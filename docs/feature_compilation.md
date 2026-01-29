# Feature Compilation

This document describes the feature compilation system that optimizes feature flag evaluation performance using Elixir metaprogramming.

## Overview

The Unleash Elixir client supports three levels of compilation that progressively optimize feature evaluation:

1. **Constraint Operator Compilation** - Compiles individual constraint operators into closures
2. **Constraint List Compilation** - Compiles all constraints into a single function
3. **Full Feature Compilation** - Compiles the entire feature evaluation tree

## Configuration

```elixir
# config/config.exs
config :unleash, Unleash,
  constraint_precompilation: true,  # Level 1 & 2 (default: true)
  feature_compilation: true         # Level 3 (default: true)
```

## Performance Improvements

Benchmarks show significant performance gains:

| Optimization Level | Speedup | Memory Reduction |
|-------------------|---------|------------------|
| Constraint list compilation | 5.42x faster | 7.44x less |
| Full feature compilation | 10.13x faster | 15.20x less |

## How It Works

### Level 1: Constraint Operator Compilation

Individual constraint operators are compiled into closures at feature load time:

```elixir
# Before (runtime evaluation)
%{"operator" => "IN", "values" => ["a", "b"]}

# After (compiled)
%{"operator" => fn x -> x in ["a", "b"] end, "values" => ["a", "b"]}
```

Benefits:
- Pre-parsed numeric/date values
- Pre-compiled binary patterns for string operations
- Eliminates operator string matching at runtime

### Level 2: Constraint List Compilation

All constraints for a strategy are compiled into a single function:

```elixir
# Compiled function
fn context ->
  # Pre-computed field atoms (no Recase.to_snake at runtime)
  user_id = Map.get(context, :user_id)
  app_name = Map.get(context, :app_name)

  # All constraint checks inlined
  (user_id in ["user1", "user2"]) and (app_name in ["app1", "app2"])
end
```

Benefits:
- Pre-computed context field names (snake_case conversion done once)
- Eliminates `Enum.all?` iteration overhead
- Single function call instead of multiple constraint checks

### Level 3: Full Feature Compilation

The entire feature evaluation tree is compiled into a single function:

```elixir
# Stored in Feature struct
%Feature{
  name: "my-feature",
  enabled: true,
  strategies: [...],
  __compiled_enabled__: fn context -> {boolean, strategy_evaluations} end
}
```

Benefits:
- Pre-resolved strategy modules (eliminates `Enum.find` lookup)
- All constraint functions pre-compiled
- Single function call for entire feature evaluation

## Architecture

### Compilation Flow

```
Feature JSON from server
    │
    ▼
Features.from_map/1
    │
    ▼
Feature.from_map/1
    ├── Strategy.update_map/1 (for each strategy)
    │   ├── Constraint.from_map/1 (operator compilation)
    │   ├── Adds __strategy_module__ (pre-resolved)
    │   └── Adds __compiled_constraints__ (list compilation)
    │
    └── FeatureCompiler.compile_feature/1 (full compilation)
        └── Stores in __compiled_enabled__ field
```

### Evaluation Flow

```
Unleash.enabled?("feature", context)
    │
    ▼
Feature.enabled?(feature, context)
    │
    ├── If __compiled_enabled__ exists:
    │   └── compiled_fn.(context) → {result, evaluations}
    │
    └── Else (fallback):
        └── Iterate strategies with Enum.map/any?
```

## Key Files

| File | Description |
|------|-------------|
| `lib/unleash/strategy/constraint.ex` | Constraint compilation (`compile_all/2`, `compile_single_constraint/1`) |
| `lib/unleash/strategy.ex` | Strategy module pre-resolution, compiled constraints integration |
| `lib/unleash/feature_compiler.ex` | Full feature tree compilation |
| `lib/unleash/feature.ex` | Feature struct with `__compiled_enabled__` field |
| `lib/unleash/config.ex` | Configuration options |

## API Reference

### Constraint.compile_all/2

```elixir
@spec compile_all(list(map()) | nil, boolean()) :: (map() -> boolean())

# Compiles a list of constraints into a single function
compiled_fn = Constraint.compile_all(constraints, true)
result = compiled_fn.(context)  # => true | false
```

### FeatureCompiler.compile_feature/1

```elixir
@spec compile_feature(%{enabled: boolean(), strategies: list()}) ::
  (map() -> {boolean(), list()}) | nil

# Compiles a feature into a single evaluation function
compiled_fn = FeatureCompiler.compile_feature(feature)
{result, strategy_evaluations} = compiled_fn.(context)
```

## Benchmarking

Run benchmarks to measure performance:

```bash
# Full benchmark
mix benchmark.feature

# Quick benchmark
mix benchmark.feature --quick

# With stress test (100 contexts)
mix benchmark.feature --stress

# Constraint-only benchmark
mix benchmark.constraint
```

## Backward Compatibility

All compilation features maintain backward compatibility:

- Configuration flags enable/disable each level
- Fallback clauses handle non-compiled data structures
- Public API unchanged (`Unleash.enabled?/3`, etc.)

## Trade-offs

| Aspect | With Compilation | Without Compilation |
|--------|-----------------|---------------------|
| Runtime speed | Fast | Slower |
| Memory per feature | Slightly higher (closures) | Lower |
| Initial load time | Slightly longer | Faster |
| Debugging | Closures in data | Plain data |

## Disabling Compilation

To disable compilation (for debugging or testing):

```elixir
# Disable all compilation
config :unleash, Unleash,
  constraint_precompilation: false,
  feature_compilation: false

# Disable only full feature compilation
config :unleash, Unleash,
  constraint_precompilation: true,
  feature_compilation: false
```
