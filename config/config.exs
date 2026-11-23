import Config

config :phoenix, :json_library, Jason

if config_env() == :test, do: import_config("test.exs")
