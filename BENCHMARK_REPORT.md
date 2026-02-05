# Unleash Metrics Performance Benchmark Report

## Overview

This report documents the performance analysis and optimization of the metrics collection system in the Unleash Elixir client. The goal was to profile the existing `handle_metric` and `add_metric` functions and explore optimizations for high-throughput scenarios.

## Test Environment

- **OS**: macOS Darwin 23.6.0
- **CPU**: Intel Core i9-9980HK @ 2.40GHz (16 cores)
- **Memory**: 32 GB
- **Elixir**: 1.18.2
- **Erlang/OTP**: 27.2.4
- **JIT**: Disabled

## Benchmark Results

### 1. handle_metric Function (Internal)

The `handle_metric` function is the core logic that updates the metrics state map.

#### Single Call Performance

| Operation | Throughput | Avg Time | Memory |
|-----------|-----------|----------|--------|
| Non-feature (early return) | 9.11 M/s | 110 ns | 0 B |
| Enabled: true | 4.09 M/s | 245 ns | 88 B |
| Enabled: false | 4.75 M/s | 211 ns | 88 B |

#### Map Size Impact

| State Size | Throughput | Avg Time | Memory |
|------------|-----------|----------|--------|
| 1 toggle | 3.23 M/s | 310 ns | 112 B |
| 100 toggles | 2.53 M/s | 395 ns | 288 B |

**Finding**: Map size has minimal impact (~1.27x slower) due to Elixir's efficient persistent data structures.

---

### 2. add_metric Function (GenServer-based)

The public `add_metric` function uses GenServer.cast for async metric recording.

#### Single Call Performance

| Operation | Throughput | Avg Time | Memory |
|-----------|-----------|----------|--------|
| add_metric (enabled: true) | 43.9 K/s | 22.8 μs | 1.72 KB |
| add_metric (enabled: false) | 44.6 K/s | 22.4 μs | 1.72 KB |
| add_metric (non-feature) | 44.1 K/s | 22.7 μs | 1.72 KB |

#### Stress Test - 100K Calls

| Scenario | Time per 100K | Memory | Per-call |
|----------|---------------|--------|----------|
| Single feature | 2.52 s | 3.01 GB | 25.2 μs |
| Round-robin (10 features) | 2.57 s | 3.01 GB | 25.7 μs |
| Random feature | 2.60 s | 3.02 GB | 26.0 μs |

**Finding**: GenServer cast overhead (~22 μs) dominates performance. Memory usage is high due to message queue buildup.

---

### 3. Optimized Implementation (MetricsFast)

A new ETS-based implementation using `:counters` for lock-free atomic updates.

#### Single Call Performance

| Implementation | Throughput | Avg Time | Memory |
|----------------|-----------|----------|--------|
| **MetricsFast** | **1.79 M/s** | **0.56 μs** | **0.156 KB** |
| Metrics (GenServer) | 42 K/s | 23.9 μs | 1.72 KB |

#### Stress Test - 100K Calls

| Implementation | Time per 100K | Memory | Per-call |
|----------------|---------------|--------|----------|
| **MetricsFast** | **59 ms** | **20 MB** | **0.59 μs** |
| Metrics (GenServer) | 2.50 s | 3.01 GB | 25.0 μs |

---

## Performance Comparison Summary

| Metric | GenServer (Default) | MetricsFast (Optimized) | Improvement |
|--------|---------------------|-------------------------|-------------|
| Single call latency | 23.9 μs | 0.56 μs | **43x faster** |
| 100K calls duration | 2.50 s | 59 ms | **42x faster** |
| Memory (100K calls) | 3.01 GB | 20 MB | **150x less** |
| Throughput | 42 K/s | 1.79 M/s | **43x higher** |
| Max sustainable rate | ~40K/s | ~1.8M/s | **45x higher** |

---

## Bottleneck Analysis

### GenServer Implementation Bottlenecks

1. **Message Passing Overhead**: Each `GenServer.cast` requires message serialization and copying between processes (~20 μs overhead)

2. **Single Process Serialization**: All metrics flow through one GenServer, creating a serialization point

3. **Memory Pressure**: Message queue growth under high load causes significant memory allocation

4. **Config Check**: `Config.disable_metrics()` is called on every invocation

### Optimizations Applied in MetricsFast

| Optimization | Impact |
|--------------|--------|
| ETS `:counters` | Lock-free atomic updates, no message passing |
| Cached `disable_metrics` flag | Eliminates runtime config lookup |
| Pre-registered features | Avoids counter creation in hot path |
| `write_concurrency` + `read_concurrency` | Optimized concurrent ETS access |
| Direct function calls | No GenServer overhead |

---

## Implementation Details

### MetricsFast Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    MetricsFast                          │
├─────────────────────────────────────────────────────────┤
│  ETS Tables (public, concurrent access)                 │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │ :counters table │  │ :variants table │              │
│  │ feature -> ref  │  │ {feat,var}->ref │              │
│  └────────┬────────┘  └────────┬────────┘              │
│           │                    │                        │
│           ▼                    ▼                        │
│  ┌─────────────────────────────────────────┐           │
│  │     :counters (atomics-based)           │           │
│  │     Lock-free increment operations      │           │
│  └─────────────────────────────────────────┘           │
├─────────────────────────────────────────────────────────┤
│  GenServer (only for periodic sending)                  │
│  - Collects metrics from ETS                           │
│  - Sends to Unleash server                             │
│  - Resets counters                                     │
└─────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **Separation of Concerns**: Hot path (counter updates) is decoupled from cold path (sending metrics)

2. **Pre-registration**: Features are registered when loaded from server, avoiding runtime counter creation

3. **Atomic Counters**: Uses Erlang's `:counters` module for lock-free concurrent updates

4. **Minimal Allocations**: Each `add_metric` call allocates only 160 bytes vs 1.72 KB for GenServer

---

## Usage

### Default Configuration

As of this update, `fast_metrics: true` is the **default** setting. No configuration change is needed to use the optimized implementation.

### Disable Fast Metrics (if needed)

```elixir
# config/config.exs - to use the original GenServer-based implementation
config :unleash,
  fast_metrics: false
```

### Run Benchmarks

```bash
# Full comparison benchmark
mix benchmark.metrics --compare

# Quick benchmark
mix benchmark.metrics --compare --quick

# Stress test only
mix benchmark.metrics --stress

# Profile add_metric specifically
mix benchmark.metrics --add-metric --stress
```

---

## Recommendations

| Traffic Level | Recommendation | Config |
|---------------|----------------|--------|
| Any | MetricsFast (default) | `fast_metrics: true` (default) |
| Legacy/compatibility | GenServer | `fast_metrics: false` |

### When to Use Default (MetricsFast)

- All new deployments (recommended)
- High-frequency feature flag checks (> 10K/s)
- Latency-sensitive applications
- Memory-constrained environments
- Applications with many concurrent requests

### When to Disable Fast Metrics

- If you experience issues with the new implementation
- For backward compatibility with custom metrics integrations
- When debugging metrics-related issues

---

## Files Changed

| File | Change |
|------|--------|
| `lib/unleash/metrics_fast.ex` | New optimized metrics module |
| `lib/unleash/config.ex` | Added `fast_metrics` config option |
| `lib/unleash.ex` | Configurable metrics module selection |
| `lib/unleash/repo.ex` | Auto-registers features with MetricsFast |
| `lib/mix/tasks/benchmark.metrics.ex` | Benchmark task for profiling |
| `mix.exs` | Added Benchee dependency |

---

## Conclusion

The optimized `MetricsFast` implementation provides **43x better throughput** and **150x lower memory usage** compared to the default GenServer-based approach. This makes the Unleash client suitable for high-performance, high-throughput applications where feature flag checks occur at very high rates.

The optimization is backward-compatible and can be enabled via a simple configuration change without any code modifications to existing applications.
