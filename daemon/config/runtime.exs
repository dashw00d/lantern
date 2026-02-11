import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/lantern start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :lantern, LanternWeb.Endpoint, server: true
end

config :lantern, LanternWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("LANTERN_PORT", "4777"))]

# Lantern-specific configuration
config :lantern,
  workspace_roots: String.split(System.get_env("LANTERN_WORKSPACES", Path.expand("~/sites")), ":"),
  tld: System.get_env("LANTERN_TLD", ".glow"),
  state_dir: System.get_env("LANTERN_STATE_DIR", Path.expand("~/.config/lantern")),
  php_fpm_socket: System.get_env("LANTERN_PHP_FPM_SOCKET", "/run/php/php8.3-fpm.sock"),
  port_range_start: String.to_integer(System.get_env("LANTERN_PORT_RANGE_START", "41000")),
  port_range_end: String.to_integer(System.get_env("LANTERN_PORT_RANGE_END", "42000"))

if config_env() == :prod do
  # Lantern is a local daemon — use a stable default secret key base.
  # This is only used for signing cookies/sessions on localhost.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      "lantern-local-daemon-secret-key-base-that-is-long-enough-for-phoenix-64-chars!!"

  config :lantern, LanternWeb.Endpoint,
    url: [host: "127.0.0.1"],
    http: [ip: {127, 0, 0, 1}],
    secret_key_base: secret_key_base
end
