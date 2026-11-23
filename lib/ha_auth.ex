defmodule HaAuth do
  @moduledoc """
  Sign in to a Phoenix app through Home Assistant, three ways, all on one
  login page (`HaAuth.Web.LoginLive`):

    1. **Kiosk Satellite**, when the page runs there with "Share Home
       Assistant connection" on: no button, the kiosk's HA user is signed in
       (`HaAuth.KioskSignIn`). Needs `kiosk: true` and an admin `token`.
    2. **QR code**: a signed-in phone scans it and approves the screen
       (`HaAuth.Pairings`).
    3. **"Sign in with Home Assistant"**: HA's own OAuth2 login
       (IndieAuth, nothing to register in HA).

  HA admins may always sign in; other HA users only when their id is in
  `allowed_users`. The session keeps only `%{"id", "name", "admin"}`,
  never an HA token. See the README for wiring it into an app.
  """

  @doc "The signed-in user in a Plug/LiveView session, or nil (re-checks access)."
  defdelegate user(session), to: HaAuth.Session
end
