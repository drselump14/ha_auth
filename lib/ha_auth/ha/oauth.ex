defmodule HaAuth.HA.OAuth do
  @moduledoc """
  Home Assistant's OAuth2 (IndieAuth flavour): no client registration, the
  app's base URL is the `client_id` and the redirect URI is on the same
  host. See https://developers.home-assistant.io/docs/auth_api/

  The browser goes to `:auth_url`; the code exchange, user lookup and
  revoke go server-side to `:ha_url`. The HA tokens are revoked as soon as
  the user is known. Swap in a stub with `config :ha_auth, :oauth, Mod`.
  """

  alias HaAuth.Config
  alias HaAuth.HA.OneShot

  @callback authorize_url(
              client_id :: String.t(),
              redirect_uri :: String.t(),
              state :: String.t()
            ) ::
              String.t()
  @callback sign_in(code :: String.t(), client_id :: String.t()) :: {:ok, map} | {:error, term}

  @behaviour __MODULE__

  @doc "The configured implementation (this module unless stubbed)."
  def impl, do: Config.get(:oauth, __MODULE__)

  @impl true
  def authorize_url(client_id, redirect_uri, state) do
    query =
      URI.encode_query(
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        state: state
      )

    Config.auth_url() <> "/auth/authorize?" <> query
  end

  @impl true
  def sign_in(code, client_id) do
    with {:ok, tokens} <- exchange(code, client_id) do
      result = current_user(tokens["access_token"])
      revoke(tokens["refresh_token"])
      result
    end
  end

  defp exchange(code, client_id) do
    case post("/auth/token", grant_type: "authorization_code", code: code, client_id: client_id) do
      {:ok, %Req.Response{status: 200, body: %{"access_token" => _} = tokens}} -> {:ok, tokens}
      {:ok, %Req.Response{status: status}} -> {:error, {:token_exchange, status}}
      {:error, reason} -> {:error, {:token_exchange, reason}}
    end
  end

  defp revoke(nil), do: :ok

  defp revoke(refresh_token) do
    _ = post("/auth/revoke", token: refresh_token)
    :ok
  end

  defp post(path, form) do
    Req.post(Config.ha_url() <> path,
      form: form,
      connect_options: [transport_opts: Config.ssl_options()],
      retry: false,
      receive_timeout: 10_000
    )
  end

  # HA has no REST "who am I"; the websocket's auth/current_user is it.
  defp current_user(access_token) do
    case OneShot.call(access_token, %{type: "auth/current_user"}) do
      {:ok, %{"id" => id, "name" => name} = user} ->
        {:ok, %{"id" => id, "name" => name, "admin" => user["is_admin"] == true}}

      {:ok, other} ->
        {:error, {:current_user, other}}

      {:error, reason} ->
        {:error, {:current_user, reason}}
    end
  end
end
