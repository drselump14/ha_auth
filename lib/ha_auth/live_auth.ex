defmodule HaAuth.LiveAuth do
  @moduledoc """
  `on_mount` for LiveViews: `live_session :app, on_mount: {HaAuth.LiveAuth,
  :require_user}` assigns `:current_user` or sends the browser to `/login`.
  """

  def on_mount(:require_user, _params, session, socket) do
    case HaAuth.Session.user(session) do
      nil -> {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
      user -> {:cont, Phoenix.Component.assign(socket, :current_user, user)}
    end
  end
end
