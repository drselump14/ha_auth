defmodule HaAuth.Web.AuthController do
  @moduledoc "The ways in (HA's OAuth, Kiosk Satellite, an approved QR code) and logout."
  use Phoenix.Controller, formats: [:html]

  import Plug.Conn

  require Logger

  alias HaAuth.{Access, Config, KioskSignIn, Pairings, Session}
  alias HaAuth.HA.{OAuth, Users}

  # Off to HA's authorize page; `state` ties the callback to this browser.
  def authorize(conn, _params) do
    state = Session.random_id()

    conn
    |> put_session("ha_auth_oauth_state", state)
    |> redirect(external: OAuth.impl().authorize_url(client_id(conn), redirect_uri(conn), state))
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    expected = get_session(conn, "ha_auth_oauth_state")
    conn = delete_session(conn, "ha_auth_oauth_state")

    with true <- is_binary(expected) and Plug.Crypto.secure_compare(state, expected),
         {:ok, user} <- OAuth.impl().sign_in(code, client_id(conn)) do
      sign_in(conn, user)
    else
      false ->
        failed(conn, "Sign-in expired, please try again.")

      {:error, reason} ->
        Logger.warning("HaAuth: HA sign-in failed: #{inspect(reason)}")
        failed(conn, "Home Assistant didn't accept the sign-in.")
    end
  end

  # HA sends ?error=access_denied when the user cancels.
  def callback(conn, _params), do: failed(conn, "Sign-in was cancelled.")

  # The login page on a Kiosk Satellite tablet confirmed its nonce through
  # HA; whoever HA says made that call is signed in.
  def kiosk(conn, _params) do
    nonce = get_session(conn, "ha_auth_kiosk_nonce")
    conn = delete_session(conn, "ha_auth_kiosk_nonce")

    with true <- Config.kiosk?() and is_binary(nonce),
         {:ok, user_id} <- KioskSignIn.await(nonce, Config.kiosk_timeout()),
         {:ok, user} <- Users.find(user_id) do
      sign_in(conn, user)
    else
      false ->
        failed(conn, "Sign-in expired, please try again.")

      {:error, reason} ->
        Logger.warning("HaAuth: kiosk sign-in failed: #{inspect(reason)}")
        failed(conn, "The kiosk couldn't sign in through Home Assistant.")
    end
  end

  # The login page saw its QR code approved; the approver is signed in here.
  def pair_finish(conn, _params) do
    code = get_session(conn, "ha_auth_pair_code")
    conn = delete_session(conn, "ha_auth_pair_code")

    case Pairings.take(code) do
      {:ok, user} -> sign_in(conn, user)
      :error -> failed(conn, "The QR code expired, please scan again.")
    end
  end

  def logout(conn, _params), do: conn |> Session.log_out() |> redirect(to: "/login")

  defp sign_in(conn, user) do
    if Access.can_sign_in?(user) do
      return_to = Session.return_to(conn)
      conn |> Session.log_in(user) |> redirect(to: return_to)
    else
      failed(
        conn,
        "Your Home Assistant account isn't allowed here. Ask an admin to add your HA user id."
      )
    end
  end

  defp failed(conn, message), do: conn |> put_flash(:error, message) |> redirect(to: "/login")

  # IndieAuth: client_id is the app's root URL; the redirect is on the same host.
  defp client_id(conn), do: endpoint_module(conn).url() <> "/"
  defp redirect_uri(conn), do: endpoint_module(conn).url() <> "/auth/callback"
end
