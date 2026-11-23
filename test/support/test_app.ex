defmodule HaAuth.Test.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>{assigns[:page_title]}</title>
      </head>
      <body>{@inner_content}</body>
    </html>
    """
  end
end

defmodule HaAuth.Test.ErrorHTML do
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule HaAuth.Test.HomeLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket), do: {:ok, socket}
  def render(assigns), do: ~H|<p id="home">Hello {@current_user["name"]}</p>|
end

defmodule HaAuth.Test.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import HaAuth.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HaAuth.Test.Layouts, :root}
    plug :protect_from_forgery
  end

  ha_auth_routes()

  scope "/" do
    pipe_through [:browser, :ha_auth_user]

    live_session :app, on_mount: {HaAuth.LiveAuth, :require_user} do
      live "/", HaAuth.Test.HomeLive
    end
  end
end

defmodule HaAuth.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :ha_auth

  @session_options [store: :cookie, key: "_ha_auth_test", signing_salt: "test1234"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug HaAuth.Test.Router
end

defmodule HaAuth.Test.OAuthStub do
  @moduledoc "Code \"good\" signs in admin u1, \"aiko\" non-admin u2, anything else fails."
  @behaviour HaAuth.HA.OAuth

  @impl true
  def authorize_url(client_id, redirect_uri, state) do
    "https://ha.test/auth/authorize?" <>
      URI.encode_query(client_id: client_id, redirect_uri: redirect_uri, state: state)
  end

  @impl true
  def sign_in("good", _), do: {:ok, %{"id" => "u1", "name" => "Selump", "admin" => true}}
  def sign_in("aiko", _), do: {:ok, %{"id" => "u2", "name" => "Aiko", "admin" => false}}
  def sign_in(_code, _), do: {:error, :invalid_code}
end

defmodule HaAuth.Test.UsersStub do
  def users do
    {:ok,
     [
       %{"id" => "u1", "name" => "Selump", "admin" => true, "active" => true},
       %{"id" => "u2", "name" => "Aiko", "admin" => false, "active" => true}
     ]}
  end
end

defmodule HaAuth.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint HaAuth.Test.Endpoint
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import HaAuth.ConnCase
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @admin %{"id" => "u1", "name" => "Selump", "admin" => true}

  @doc "A conn signed in as `user` (default: the admin u1)."
  def log_in(conn, user \\ @admin) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session("ha_auth_user", user)
  end

  @doc "Set an :ha_auth env key for one test."
  def put_ha_auth_env(key, value) do
    old = Application.fetch_env(:ha_auth, key)
    Application.put_env(:ha_auth, key, value)

    ExUnit.Callbacks.on_exit(fn ->
      case old do
        {:ok, v} -> Application.put_env(:ha_auth, key, v)
        :error -> Application.delete_env(:ha_auth, key)
      end
    end)
  end
end
