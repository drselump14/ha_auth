import Config

config :ha_auth,
  oauth: HaAuth.Test.OAuthStub,
  users_source: HaAuth.Test.UsersStub,
  kiosk_timeout: 200

config :ha_auth, HaAuth.Test.Endpoint,
  url: [host: "clock.test", scheme: "https", port: 443],
  secret_key_base: String.duplicate("k", 64),
  live_view: [signing_salt: "ha_auth_test"],
  render_errors: [formats: [html: HaAuth.Test.ErrorHTML]],
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
