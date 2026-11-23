defmodule HaAuth.Config do
  @moduledoc """
  Settings, from `config :ha_auth, ...` (usually in `config/runtime.exs`):

    * `:ha_url` - Home Assistant as the server reaches it (required)
    * `:auth_url` - where browsers go for HA's login page (default `:ha_url`)
    * `:token` - long-lived HA token. Only needed for Kiosk Satellite
      sign-in, and then it must belong to an HA admin
    * `:verify_ssl` - check HA's certificate (default false: LAN HA is
      usually self-signed)
    * `:allowed_users` - non-admin HA user ids that may sign in (default [])
    * `:kiosk` - offer Kiosk Satellite sign-in (default false)
    * `:after_sign_in_path` - where to go when no page was asked for (default "/")
    * `:app_name` - heading on the login page (default "Sign in")
    * `:auth_disabled` - skip sign-in, everyone is a dev admin (dev only!)
  """

  def get(key, default \\ nil), do: Application.get_env(:ha_auth, key, default)

  def ha_url, do: (get(:ha_url) || raise("config :ha_auth, :ha_url is missing")) |> trim()
  def auth_url, do: trim(get(:auth_url) || ha_url())
  def token, do: get(:token)
  def token?, do: token() not in [nil, ""]
  def kiosk?, do: get(:kiosk, false) == true
  def allowed_users, do: get(:allowed_users) || []
  def after_sign_in_path, do: get(:after_sign_in_path, "/")
  def app_name, do: get(:app_name, "Sign in")
  def auth_disabled?, do: get(:auth_disabled, false) == true
  def kiosk_timeout, do: get(:kiosk_timeout, 5_000)

  def ssl_options, do: if(get(:verify_ssl, false), do: [], else: [verify: :verify_none])

  def websocket_url, do: String.replace(ha_url(), ~r/^http/, "ws") <> "/api/websocket"

  defp trim(url), do: String.trim_trailing(url, "/")
end
