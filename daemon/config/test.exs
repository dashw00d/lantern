import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lantern, LanternWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "k9VMKnvHF0ONWW3bSRQvCqK2u04CDOaiIbJ4OioAFAKBH/PB4pBPMZN3JFTvdz3u",
  server: false

# Disable self-registration during tests (no Caddy available)
# Use isolated state directory so tests don't corrupt dev/prod state.json
config :lantern, state_dir: Path.join(System.tmp_dir!(), "lantern-test-#{System.pid()}")

config :lantern, self_register: false
config :lantern, discovery_worker_enabled: false
config :lantern, shutdown_stop_services: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
