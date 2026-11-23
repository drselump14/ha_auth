defmodule HaAuth.Access do
  @moduledoc """
  Who may sign in: HA admins always, other HA users when their id is in
  `config :ha_auth, :allowed_users`. Checked at sign-in and again on every
  request and LiveView mount, so dropping someone locks them out at once.
  """

  @doc ~s|Session user map (`%{"id", "name", "admin"}`) may use the app?|
  def can_sign_in?(%{"admin" => true}), do: true
  def can_sign_in?(%{"id" => id}) when is_binary(id), do: id in HaAuth.Config.allowed_users()
  def can_sign_in?(_), do: false
end
