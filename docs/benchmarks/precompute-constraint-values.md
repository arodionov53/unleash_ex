# Benchmark: Precompute Constraint Values

**Date:** 2026-08-14  
**Branch:** `precompute-constraint-values`  
**Hardware:** Apple M2 Pro, 12 cores, 16 GB RAM  
**Runtime:** Elixir 1.20.2, Erlang/OTP 29.0.2, JIT enabled  

## Summary

Pre-parsing invariant constraint `"value"` strings (numeric, semver, date) at
poll time eliminates redundant string parsing on every `enabled?`/`get_variant`
call. The optimization delivers **2–6× throughput improvement** depending on the
operator type.

## Results

| Constraint type | Without precompute | With precompute | Speedup | Latency saved |
|---|---|---|---|---|
| Numeric (`NUM_GTE`) | 0.96 M ips (1.05 μs) | 5.53 M ips (0.18 μs) | **5.78×** | 0.86 μs |
| Semver (`SEMVER_GT`) | 161 K ips (6.20 μs) | 363 K ips (2.75 μs) | **2.25×** | 3.45 μs |
| Date (`DATE_AFTER`) | 0.59 M ips (1.69 μs) | 3.00 M ips (0.33 μs) | **5.06×** | 1.35 μs |
| Mixed (all 3) | 115 K ips (8.70 μs) | 317 K ips (3.16 μs) | **2.75×** | 5.54 μs |

## Analysis

- **Numeric** — the largest relative gain (5.78×). `Integer.parse/2` + `Float.parse/1`
  on every call is expensive relative to a simple number comparison.
- **Date** — similar gain (5.06×). `DateTime.from_iso8601/1` involves regex matching
  and struct construction; skipping it on the hot path is significant.
- **Semver** — smaller relative gain (2.25×) because `mk_semver/1` must still parse
  the *context* value (user-supplied at request time). Only the server-side constraint
  value is pre-parsed. Still a meaningful absolute saving of 3.45 μs per call.
- **Mixed** — representative of a real feature with multiple constraints. A feature
  guarded by 3 typed constraints saves ~5.5 μs per evaluation.

## How to reproduce

```sh
mix benchmark.constraint
```

## What was changed

1. Added `Constraint.precompute/1` — called once per constraint at poll time via
   `Strategy.update_map/1`. Stashes pre-parsed values under `"parsedValue"`,
   `"parsedSemver"`, or `"parsedDate"` keys.
2. Updated `check/3` clauses — fast-path clauses match pre-parsed keys first;
   fallback clauses preserve backward compatibility.
3. Fixed `mk_semver/1` — no longer crashes on malformed versions; strips
   pre-release/build metadata, returns `:error` on parse failure.
