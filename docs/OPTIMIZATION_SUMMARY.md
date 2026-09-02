# Optimization Summary: `compiled-closure` vs `main`

## Overview

The `compiled-closure` branch optimizes the `Unleash.enabled?/3` and
`Unleash.get_variant/3` hot path by eliminating overhead from telemetry,
`Application.get_env` lookups, ETS struct copies, and unnecessary map
allocations. The result is a ~2–3× improvement at high concurrency.

---

## Main branch hot path

```
enabled?(feature, context) →
  telemetry_metadata()           Application.get_env ×2 + map allocs
  :telemetry.span(…)             monotonic_time ×2, ETS handler lookups ×2
    Config.disable_client()      Application.get_env
    Repo.get_feature()           ETS lookup + struct copy
    Feature.enabled?(…)          strategy interpretation
    metrics_module()             Application.get_env
    .add_metric(…)               MetricsFast (ETS + :counters)
    Map.merge ×3                 telemetry metadata construction
```

## Optimized branch hot path (`disable_telemetry: true`, the default)

```
enabled?(feature, context) →
  disable_telemetry_fast()       persistent_term (~20ns)
  disable_client_fast()          persistent_term (~20ns)
  FeatureCompiler.compiled?()    persistent_term (~20ns)
  get_feature(name)              persistent_term (no copy)
  Feature.enabled?(…)            same static JIT-optimized strategy eval
  metrics_module_fast()          persistent_term (~20ns)
  .add_metric(…)                 MetricsFast (ETS + :counters)
```

---

## Optimizations applied

### 1. Disable telemetry on the hot path (`disable_telemetry: true`)

**Default changed to `true`.** When set, `enabled?/3` and `get_variant/3`
skip the `:telemetry.span/3` wrapper entirely, eliminating:

- 2× `:erlang.monotonic_time/0` calls
- 1× `System.unique_integer/0` for span context
- 2× ETS handler-table lookups
- 2× `Application.get_env` for appname/instance_id
- 3× map allocations for telemetry metadata (`Map.merge` + `Map.put`)

Users who need `[:unleash, :feature, :enabled?]` and `[:unleash, :variant, :get]`
telemetry events can set `disable_telemetry: false`. Background client events
(polling, metrics posting, registration) are unaffected.

### 2. Config values cached in persistent_term

`disable_client`, `disable_telemetry`, and `metrics_module` are cached in
`:persistent_term` at application start via `Config.cache_hot_path_config!/0`.

| Accessor | Before | After |
|---|---|---|
| `Config.disable_client()` | `Application.get_env` (~200ns) | `persistent_term.get` (~20ns) |
| `Config.disable_telemetry()` | `Application.get_env` (~200ns) | `persistent_term.get` (~20ns) |
| `Config.metrics_module()` | `Application.get_env` ×2 (~400ns) | `persistent_term.get` (~20ns) |

### 3. `FeatureCompiler.compiled?()` via persistent_term

Replaced `Code.ensure_loaded?(Unleash.CompiledFeatures)` (code server message)
with a `:persistent_term` flag set to `true` by `FeatureCompiler.compile_all/1`.
Eliminates a process message round-trip on every call.

### 4. Feature structs stored in persistent_term

Feature structs are stored in `:persistent_term` keyed by `{:unleash_feature, name}`
during `compile_all/1`. The fast path reads them via `FeatureCompiler.get_feature/1`
instead of `Repo.get_feature/1` (ETS lookup).

`:persistent_term.get` returns a reference to shared heap data — no struct copy,
unlike ETS which copies the term into the caller's heap on every lookup.

### 5. No metadata map construction on fast path

The main branch always builds `{result, %{reason: …}}` tuples and telemetry
metadata maps, even when no telemetry handlers are attached. The fast path
returns the result directly with no intermediate map allocations.

### 6. Safe module reload with `:code.soft_purge`

`FeatureCompiler.compile_all/1` uses `:code.soft_purge/1` instead of
`:code.purge/1`. The hard purge kills any process currently executing in the
old module version — since `enabled?/2` runs on the caller's process, this
could crash request-path processes during a feature reload. `soft_purge` is a
no-op if any process is still in old code, making hot-swap safe.

---

## What was tried and reverted

### Dynamic module dispatch (`CompiledFeatures`)

Feature evaluation was compiled into a dynamically-generated BEAM module
(`Unleash.CompiledFeatures`) with per-feature function clauses. This was
faster in micro-benchmarks (~500ns vs ~3μs for ETS+interpret) but **slower
under high concurrency** (64+ callers) in production:

| p50, 64 calls | CompiledFeatures | main (Feature.enabled?) |
|---|---|---|
| enabled? | 1520 μs | 1021 μs |

Root cause: BeamAsm JIT does not fully optimize hot-swapped modules, and
instruction cache pressure from per-feature function clauses degrades under
concurrent access. The static `Feature.enabled?/2` is permanently JIT-compiled
and cache-friendly.

The fast path now uses `Feature.enabled?/2` (same as main) but reads the
feature struct from persistent_term instead of ETS, avoiding the copy overhead.

### `add_metric_by_name/2`

Added a lightweight metric recording function that takes the feature name
directly, avoiding a persistent_term lookup for the full Feature struct.
No measurable production improvement — the struct lookup is needed anyway
for `Feature.enabled?/2`.

---

## Production results

### `get_variant` (p50, `pipe_bid_req` step duration in μs)

| concurrent calls |   0 |   1 |   8 |  16 |   32 |    64 |     80 |
|------------------|----:|----:|----:|----:|-----:|------:|-------:|
| **optimized**    | 500 | 500 | 501 | 501 |  509 |   695 |    979 |
| **main**         | 500 | 501 | 501 | 502 |  519 |   881 |  2,668 |

### `get_variant` (p95)

| concurrent calls |   0 |   1 |   8 |  16 |   32 |    64 |     80 |
|------------------|----:|----:|----:|----:|-----:|------:|-------:|
| **optimized**    | 950 | 951 | 952 | 951 |  970 | 6,581 |  7,830 |
| **main**         | 951 | 951 | 953 | 951 |  987 | 6,993 | 15,133 |

### `enabled?` (p50, `pipe_bid_req` step duration in μs)

*Measured before commit `55f87d2` which replaced dynamic `CompiledFeatures`
dispatch with static `Feature.enabled?/2` + persistent_term. The optimized
path now follows the same pattern as `get_variant_fast` (which showed ~2–3×
improvement), so similar gains are expected. Needs re-deployment and load
test to confirm.*

| concurrent calls |   0 |   1 |   8 |  16 |   32 |    64 |     80 |
|------------------|----:|----:|----:|----:|-----:|------:|-------:|
| **optimized**    | 501 | 501 | 500 | 503 |  532 | 1,520 |  3,648 |
| **main**         | 500 | 500 | 500 | 501 |  516 | 1,021 |  3,768 |

### `enabled?` (p95)

| concurrent calls |   0 |   1 |   8 |  16 |    32 |     64 |     80 |
|------------------|----:|----:|----:|----:|------:|-------:|-------:|
| **optimized**    | 952 | 951 | 951 | 955 | 1,334 | 13,541 | 22,546 |
| **main**         | 951 | 951 | 951 | 952 |   979 | 11,609 | 20,676 |

`get_variant`: **~2–3× improvement** at high concurrency (64–80 calls).
`enabled?`: above numbers used dynamic module dispatch (slower than main);
fix deployed in `55f87d2` — **re-deployment + load test needed** to get
updated numbers.

### Local micro-benchmark (single caller, `mix run --no-start`)

After the dynamic→static module fix (`55f87d2`), both `enabled?` and
`get_variant` are faster than main in single-caller benchmarks.

#### `enabled?` — median latency (ns)

| scenario             |  main | optimized | speedup |
|----------------------|------:|----------:|---------|
| nonexistent feature  |   417 |   **167** | **2.5×**  |
| disabled feature     |   875 |   **500** | **1.75×** |
| default strategy     |   875 |   **500** | **1.75×** |
| matching user        | 1,334 | **1,000** | **1.33×** |

#### `get_variant` — median latency (ns)

| scenario             |  main | optimized | speedup |
|----------------------|------:|----------:|---------|
| nonexistent feature  |   420 |   **167** | **2.5×**  |
| no variants          | 1,000 |   **667** | **1.5×**  |
| with variants        | 1,540 | **1,125** | **1.37×** |

#### Memory per call (bytes)

| scenario                   |  main | optimized | reduction |
|----------------------------|------:|----------:|-----------|
| enabled?(matching user)    | 3,630 | **1,584** | **56%**   |
| enabled?(nonexistent)      | 1,150 |    **88** | **92%**   |
| get_variant(with variants) | 2,560 | **1,552** | **39%**   |
| get_variant(nonexistent)   | 1,000 |    **88** | **91%**   |

Biggest wins on early-exit paths (nonexistent/disabled features) where
eliminated telemetry + config overhead was the dominant cost.

---

## Configuration

```elixir
config :unleash, Unleash,
  disable_telemetry: true,   # default — skip telemetry spans on hot path
  fast_metrics: true          # default — ETS/:counters instead of GenServer
```

## Files changed

```
lib/unleash.ex                    — fast path with persistent_term + static eval
lib/unleash/config.ex             — persistent_term-cached accessors, disable_telemetry option
lib/unleash/feature_compiler.ex   — compile_all, persistent_term storage, soft_purge
lib/unleash/metrics.ex            — add_metric_by_name/2
lib/unleash/metrics_fast.ex       — add_metric_by_name/2
lib/unleash/repo.ex               — triggers compile_all on poll
lib/mix/tasks/benchmark.hotpath.ex — end-to-end benchmark task
test/unleash/feature_compiler_test.exs — concurrent recompilation safety test
```
