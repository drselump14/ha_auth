defmodule HaAuth.Router do
  @moduledoc """
  Routes for the login page and sign-in, added to a Phoenix router with

      import HaAuth.Router

      # at the top level of the router, not inside a scope:
      ha_auth_routes()

  Options:

    * `:pipe_through` - the app's browser pipelines (default `[:browser]`);
      they need `:fetch_session`, flash and CSRF protection
    * `:root_layout` - root layout for the login and phone pages, e.g.
      `{MyAppWeb.Layouts, :root}` (default: whatever the pipelines set). It
      must load the app's `app.js` so the login page's LiveView connects.

  Adds `GET /login`, `/auth/ha`, `/auth/callback`, `/auth/kiosk`,
  `/auth/pair/finish`, `GET`/`POST /pair/:code` and `DELETE /logout`.
  """

  defmacro ha_auth_routes(opts \\ []) do
    pipelines = Keyword.get(opts, :pipe_through, [:browser])
    layout = Keyword.get(opts, :root_layout)
    live_opts = if layout, do: [root_layout: layout], else: []

    quote do
      pipeline :ha_auth_guest do
        plug HaAuth.Plug, :redirect_if_signed_in
      end

      pipeline :ha_auth_login do
        plug HaAuth.Plug, :login_codes
      end

      pipeline :ha_auth_user do
        plug HaAuth.Plug, :require_user
      end

      pipeline :ha_auth_layout do
        plug HaAuth.Router.Layout, unquote(layout)
      end

      scope "/" do
        pipe_through unquote(pipelines) ++ [:ha_auth_layout, :ha_auth_guest, :ha_auth_login]

        live_session :ha_auth_login, unquote(live_opts) do
          live "/login", HaAuth.Web.LoginLive
        end
      end

      scope "/" do
        pipe_through unquote(pipelines) ++ [:ha_auth_layout, :ha_auth_guest]

        get "/auth/ha", HaAuth.Web.AuthController, :authorize
        get "/auth/callback", HaAuth.Web.AuthController, :callback
        get "/auth/kiosk", HaAuth.Web.AuthController, :kiosk
        get "/auth/pair/finish", HaAuth.Web.AuthController, :pair_finish
      end

      scope "/" do
        pipe_through unquote(pipelines) ++ [:ha_auth_layout, :ha_auth_user]

        get "/pair/:code", HaAuth.Web.PairController, :show
        post "/pair/:code", HaAuth.Web.PairController, :approve
      end

      scope "/" do
        pipe_through unquote(pipelines)

        delete "/logout", HaAuth.Web.AuthController, :logout
      end
    end
  end

  defmodule Layout do
    @moduledoc false
    # Puts the `:root_layout` option on the auth routes, when given.
    @behaviour Plug
    @impl true
    def init(layout), do: layout
    @impl true
    def call(conn, nil), do: conn
    def call(conn, layout), do: Phoenix.Controller.put_root_layout(conn, html: layout)
  end
end
