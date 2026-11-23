defmodule HaAuth.Plug do
  @moduledoc """
  Plugs for routes:

    * `plug HaAuth.Plug, :require_user` - assigns `:current_user`, or
      remembers the page (with its query) and sends the browser to `/login`
    * `plug HaAuth.Plug, :redirect_if_signed_in` - for the login routes
    * `plug HaAuth.Plug, :login_codes` - fresh QR code and kiosk nonce for
      the login page (used by `HaAuth.Router`)
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias HaAuth.{Pairings, Session}

  @impl true
  def init(action) when action in [:require_user, :redirect_if_signed_in, :login_codes],
    do: action

  @impl true
  def call(conn, :require_user) do
    case Session.user(get_session(conn)) do
      nil ->
        conn
        |> remember_page()
        |> redirect(to: "/login")
        |> halt()

      user ->
        assign(conn, :current_user, user)
    end
  end

  def call(conn, :redirect_if_signed_in) do
    if Session.user(get_session(conn)),
      do: conn |> redirect(to: HaAuth.Config.after_sign_in_path()) |> halt(),
      else: conn
  end

  def call(conn, :login_codes) do
    conn
    |> put_session("ha_auth_pair_code", Pairings.create())
    |> put_session("ha_auth_kiosk_nonce", Session.random_id())
  end

  defp remember_page(%{method: "GET"} = conn),
    do: put_session(conn, "ha_auth_return_to", Phoenix.Controller.current_path(conn))

  defp remember_page(conn), do: conn
end
