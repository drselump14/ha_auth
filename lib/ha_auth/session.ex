defmodule HaAuth.Session do
  @moduledoc "What HaAuth keeps in the Plug session, and reading it back."

  import Plug.Conn

  alias HaAuth.{Access, Config}

  @user "ha_auth_user"
  @dev_user %{"id" => "dev", "name" => "Dev", "admin" => true}

  @doc "Sign `user` in on this conn (fresh session id against fixation)."
  def log_in(conn, user) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(@user, user)
  end

  @doc "The page the browser asked for before it had to sign in."
  def return_to(conn), do: get_session(conn, "ha_auth_return_to") || Config.after_sign_in_path()

  def log_out(conn), do: conn |> configure_session(renew: true) |> clear_session()

  @doc "The signed-in user in `session` (a map with string keys), if still allowed."
  def user(session) do
    cond do
      Config.auth_disabled?() -> @dev_user
      is_map(session[@user]) and Access.can_sign_in?(session[@user]) -> session[@user]
      true -> nil
    end
  end

  def random_id(bytes \\ 32),
    do: bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
