# HaAuth

Sign in to a Phoenix app through Home Assistant. One login page, three ways in:

1. **Kiosk Satellite**: no button. If the page runs as a Kiosk Satellite
   custom page with "Share Home Assistant connection" on, it signs in as the
   kiosk's HA user. HA itself says who made the call, so a page can't fake it.
2. **QR code**: scan it with a phone that's already signed in, tap
   **Approve**, and the screen signs in as that user. Codes last 10 minutes
   and work once.
3. **Sign in with Home Assistant**: HA's own login (OAuth2/IndieAuth;
   nothing to register in HA).

HA admins may always sign in; other HA users need their id in
`allowed_users`. The session holds only `%{"id", "name", "admin"}`, never an
HA token, and access is re-checked on every request and LiveView mount.

## Install

```elixir
# mix.exs
{:ha_auth, "~> 0.1"}
```

## Wire it up

**Config** (`config/runtime.exs`):

```elixir
config :ha_auth,
  ha_url: System.get_env("HA_URL", "http://homeassistant.local:8123"),
  # where browsers log in, if not ha_url (e.g. a hostname with a trusted cert)
  auth_url: System.get_env("HA_AUTH_URL"),
  # only for Kiosk Satellite sign-in; must be an HA *admin* token
  token: System.get_env("HA_TOKEN"),
  kiosk: true,
  allowed_users: System.get_env("ALLOWED_HA_USERS", "") |> String.split(",", trim: true),
  app_name: "Clock"

# dev only: skip sign-in
if config_env() == :dev do
  config :ha_auth, auth_disabled: System.get_env("AUTH_DISABLED") in ~w(1 true)
end
```

All keys: `HaAuth.Config`.

**Router**:

```elixir
import HaAuth.Router

pipeline :browser do
  # the usual :fetch_session, :fetch_live_flash, :protect_from_forgery, ...
end

# top level, not inside a scope
ha_auth_routes()
# options: pipe_through: [:browser], root_layout: {MyAppWeb.Layouts, :root}

scope "/", MyAppWeb do
  pipe_through [:browser, :ha_auth_user]   # pipeline defined by ha_auth_routes

  live_session :app, on_mount: {HaAuth.LiveAuth, :require_user} do
    live "/", HomeLive
  end
end
```

Pages get `@current_user`. Outside the router macro, use
`plug HaAuth.Plug, :require_user`.

Routes added: `GET /login`, `/auth/ha`, `/auth/callback`, `/auth/kiosk`,
`/auth/pair/finish`, `GET`/`POST /pair/:code`, `DELETE /logout`.

**Root layout**: the login page is a LiveView, so the root layout must load
the app's `app.js` (the default Phoenix one does). The pages bring their own
CSS; no Tailwind setup needed.

**Endpoint**: the endpoint `url` must be the public address
(`PHX_HOST`); it becomes HA's `client_id`, the OAuth redirect and the QR
link.

## Kiosk Satellite

- Add the app under **Settings > Home Assistant > Custom Pages** and turn
  on **Share Home Assistant connection**.
- Show it as a dashboard or screensaver *dashboard*. Website mode doesn't
  get `window.kioskSatellite`.
- Set `kiosk: true` and an admin `token`. HaAuth then listens for
  `call_service` events on its own HA websocket.

If the kiosk doesn't provide the bridge, the page falls back to the QR
code and the link.

## Tests in the host app

Sign a conn in with
`Plug.Conn.put_session(conn, "ha_auth_user", %{"id" => "u1", "name" => "Me", "admin" => true})`
after `Phoenix.ConnTest.init_test_session/2`. Stub HA with
`config :ha_auth, oauth: MyStub` (`HaAuth.HA.OAuth` behaviour) and
`users_source: MyUsersStub`.
