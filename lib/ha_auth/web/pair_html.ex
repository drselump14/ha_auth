defmodule HaAuth.Web.PairHTML do
  @moduledoc false
  use Phoenix.Component

  import Phoenix.Controller, only: [get_csrf_token: 0]
  import HaAuth.Web.Components

  def show(assigns) do
    ~H"""
    <.page>
      <%= if @pending do %>
        <h1>Sign in this screen?</h1>
        <p>It will be signed in as {@current_user["name"]}.</p>
        <form method="post" action={"/pair/" <> @code}>
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
          <button id="ha-auth-approve" type="submit" class="ha-auth-btn primary">Approve</button>
        </form>
      <% else %>
        <p id="ha-auth-expired">This code has expired or was already used. Scan the screen again.</p>
      <% end %>
    </.page>
    """
  end

  def done(assigns) do
    ~H"""
    <.page>
      <h1 :if={@ok} id="ha-auth-approved">Done</h1>
      <p :if={@ok}>The screen is signing in.</p>
      <p :if={!@ok} id="ha-auth-expired">
        This code has expired or was already used. Scan the screen again.
      </p>
    </.page>
    """
  end
end
