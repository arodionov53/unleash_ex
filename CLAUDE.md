# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Unleash Feature Flag Client for Elixir

This is an Elixir client library for the [Unleash Toggle Service](https://unleash.github.io/), providing feature flag functionality with support for multiple strategies, variants, metrics collection, and telemetry integration.

### Essential Development Commands

**Build Commands:**
```bash
mix compile           # Compile the project
mix format           # Format code using Elixir formatter
mix format --check-formatted  # Check code formatting without changes
make compile         # Alternative compile using Makefile
```

**Testing Commands:**
```bash
mix test             # Run all tests (uses ExUnit framework)
mix test --cover     # Run tests with coverage reporting
mix test test/path/to/specific_test.exs  # Run specific test file
mix test --only tag_name  # Run tests with specific tags
```

**Development Commands:**
```bash
make run             # Start interactive Elixir session with mix
make iex             # Start IEx without starting the application
iex -S mix           # Interactive Elixir with application loaded
mix test --no-start  # Run tests without starting the application (alias configured)
```

**Code Quality:**
```bash
mix credo --strict   # Static code analysis and linting
mix dialyzer         # Type checking and static analysis
mix deps.get         # Install dependencies
mix deps.update --all # Update all dependencies
```

### Core Architecture

**Primary Module:** `Unleash` - Main entry point providing `enabled?/2`, `enabled?/3`, and `get_variant/2` functions for feature flag checking.

**Key Components:**
- `Unleash.Repo` - GenServer that polls the Unleash server for feature flags and manages local caching
- `Unleash.Client` - HTTP client handling communication with Unleash server (features, registration, metrics)
- `Unleash.Cache` - ETS-based local cache for feature flags with DETS file backup
- `Unleash.Config` - Centralized configuration management with defaults and environment variable support
- `Unleash.MetricsFast` - Default metrics GenServer using ETS `:counters` for lock-free atomic updates (~70–100 ns/update)
- `Unleash.Metrics` - Legacy GenServer-based metrics (slower, used when `:fast_metrics` is `false`)
- `Unleash.Features` - Data structure representing feature flag collections
- `Unleash.Feature` - Individual feature flag evaluation logic

The active metrics module is selected at runtime via `Config.metrics_module/0` based on the `:fast_metrics` config value (defaults to `true`).

**Strategy System:**
- `Unleash.Strategy` - Behavior for implementing feature flag activation strategies
- `Unleash.Strategies` - Module containing all available strategies
- Built-in strategies in `lib/unleash/strategy/` including:
  - `Default` - Always on/off
  - `ActiveForUsersWithId` - User ID targeting
  - `GradualRolloutUserId`, `GradualRolloutSessionId`, `GradualRolloutRandom` - Percentage rollouts
  - `ApplicationHostname`, `RemoteAddress` - Environment-based targeting
  - `FlexibleRollout` - Advanced rollout with stickiness
  - `Constraint` - Complex constraint evaluation with compilation support

**Data Flow:**
1. Application starts → `Unleash` supervision tree initialized
2. `Unleash.Repo` polls server for features → updates `Unleash.Cache` → writes backup to DETS
3. Feature checks via `Unleash.enabled?/3` → cache lookup → strategy evaluation → metrics recording
4. `Unleash.Metrics` periodically sends usage data to server

### Configuration

Configuration is handled through `config/*.exs` files. Key settings include:
- `:url` - Unleash server API endpoint
- `:appname` - Application identifier
- `:auth_token` - Authentication (supports environment variables)
- `:features_period` - Polling interval for features (default 15 seconds)
- `:metrics_period` - Metrics sending interval (default 1 minute)
- `:strategies` - Custom strategy module
- `:disable_client` / `:disable_metrics` - Feature toggles for testing
- `:fast_metrics` - Use ETS-based `MetricsFast` instead of GenServer `Metrics` (default `true`)
- `:constraint_precompilation` - Compile constraints for better performance

### Testing Strategy

- **ExUnit** - Main testing framework
- **Mox** - Mocking library for HTTP client testing
- **StreamData** - Property-based testing
- **ExCoveralls** - Code coverage reporting
- Test structure follows standard Elixir patterns with `test/` directory
- Comprehensive strategy testing in `test/unleash/strategy/`
- Integration tests for client, repo, and metrics components

### Performance Features

- **ETS Cache** - In-memory storage for fast feature lookups
- **DETS Backup** - Persistent storage for offline operation (features stored in DETS files instead of JSON)
- **Constraint Compilation** - Pre-compiled constraints for faster evaluation (recent enhancement)
- **Telemetry Integration** - Comprehensive telemetry events for monitoring
- **HTTP Client Abstraction** - Pluggable HTTP client (default: Finch via SimpleHttp)

### Extension Points

The library is designed for extensibility:
- Custom strategies via `Unleash.Strategy` behavior
- Custom HTTP clients via configuration
- Custom constraint evaluation
- Telemetry event handlers for monitoring and metrics

### Development Environment

- **Elixir Version:** ~> 1.8 (configured in mix.exs)
- **Dependencies:** Managed via Mix, including Jason for JSON, Finch for HTTP, Telemetry for events
- **Formatter:** Configured in `.formatter.exs` with stream_data import
- **CI/CD:** GitLab CI configuration in `.gitlab-ci.yml` with build, test, and lint stages