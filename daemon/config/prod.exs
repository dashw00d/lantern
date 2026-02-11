import Config

# Lantern is a local daemon, no SSL needed
# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
