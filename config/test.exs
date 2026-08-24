import Config

# Configure to use the mock client for all tests
config :unleash, :client, Unleash.ClientMock

# Use standard GenServer metrics in tests for compatibility with existing test setup
config :unleash, :fast_metrics, false

# Enable telemetry in tests so telemetry-asserting tests work
config :unleash, :disable_telemetry, false
