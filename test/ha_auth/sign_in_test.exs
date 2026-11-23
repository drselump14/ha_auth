defmodule HaAuth.SignInTest do
  # Not async: tests change :ha_auth env.
  use HaAuth.ConnCase, async: false

  alias HaAuth.{KioskSignIn, Pairings}
  alias HaAuth.HA.Events

  defp login_page(conn) do
    conn = get(conn, "/login")
    {conn, html_response(conn, 200)}
  end

  describe "guarding pages" do
    test "pages need a sign-in and remember the page with its query", %{conn: conn} do
      conn = get(conn, "/?room=kitchen")
      assert redirected_to(conn) == "/login"
      assert get_session(conn, "ha_auth_return_to") == "/?room=kitchen"
      assert {:error, {:redirect, %{to: "/login"}}} = live(build_conn(), "/")
    end

    test "signed in, pages render and the login page redirects", %{conn: conn} do
      conn = log_in(conn)
      assert {:ok, _view, html} = live(conn, "/")
      assert html =~ "Hello Selump"
      assert redirected_to(get(conn, "/login")) == "/"
    end

    test "a non-admin needs to be in allowed_users, checked on every request", %{conn: conn} do
      conn = log_in(conn, %{"id" => "u2", "name" => "Aiko", "admin" => false})
      assert redirected_to(get(conn, "/")) == "/login"

      put_ha_auth_env(:allowed_users, ["u2"])
      assert {:ok, _view, _html} = live(conn, "/")
    end

    test "logout clears the session", %{conn: conn} do
      conn = conn |> log_in() |> delete("/logout")
      assert redirected_to(conn) == "/login"
      assert get_session(conn, "ha_auth_user") == nil
    end
  end

  describe "HA sign-in link" do
    test "the login page links to it", %{conn: conn} do
      {_conn, html} = login_page(conn)
      assert html =~ ~s(href="/auth/ha")
    end

    test "authorize sends the browser to HA with client_id, redirect_uri, state", %{conn: conn} do
      conn = get(conn, "/auth/ha")
      params = URI.decode_query(URI.parse(redirected_to(conn)).query)

      assert params["client_id"] == "https://clock.test/"
      assert params["redirect_uri"] == "https://clock.test/auth/callback"
      assert params["state"] == get_session(conn, "ha_auth_oauth_state")
    end

    test "callback signs in and returns to the page asked for", %{conn: conn} do
      conn = get(conn, "/?room=kitchen")
      conn = conn |> recycle() |> get("/auth/ha")
      state = get_session(conn, "ha_auth_oauth_state")
      conn = conn |> recycle() |> get("/auth/callback", code: "good", state: state)

      assert redirected_to(conn) == "/?room=kitchen"

      assert get_session(conn, "ha_auth_user") == %{
               "id" => "u1",
               "name" => "Selump",
               "admin" => true
             }
    end

    test "a non-admin not on the list is turned away", %{conn: conn} do
      conn = get(conn, "/auth/ha")
      state = get_session(conn, "ha_auth_oauth_state")
      conn = conn |> recycle() |> get("/auth/callback", code: "aiko", state: state)

      assert redirected_to(conn) == "/login"
      assert get_session(conn, "ha_auth_user") == nil
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "isn't allowed"
    end

    test "a wrong or missing state is rejected", %{conn: conn} do
      conn1 = get(conn, "/auth/ha")
      conn1 = conn1 |> recycle() |> get("/auth/callback", code: "good", state: "forged")
      assert get_session(conn1, "ha_auth_user") == nil

      conn2 = get(build_conn(), "/auth/callback", code: "good", state: "anything")
      assert redirected_to(conn2) == "/login"
    end

    test "HA refusing the code, or a cancel, lands on login", %{conn: conn} do
      conn1 = get(conn, "/auth/ha")
      state = get_session(conn1, "ha_auth_oauth_state")
      conn1 = conn1 |> recycle() |> get("/auth/callback", code: "bad", state: state)
      assert Phoenix.Flash.get(conn1.assigns.flash, :error) =~ "didn't accept"

      assert redirected_to(get(build_conn(), "/auth/callback", error: "access_denied")) ==
               "/login"
    end
  end

  describe "QR code" do
    defp phone, do: log_in(build_conn())

    test "the login page shows a QR code for its pending code", %{conn: conn} do
      {conn, html} = login_page(conn)
      assert html =~ ~s(id="ha-auth-qr")
      assert html =~ "<svg"
      assert Pairings.pending?(get_session(conn, "ha_auth_pair_code"))
    end

    test "phone approves, page moves on, browser is signed in as the phone's user", %{conn: conn} do
      conn = get(conn, "/?room=kitchen")
      {conn, _html} = login_page(recycle(conn))
      code = get_session(conn, "ha_auth_pair_code")
      {:ok, view, _html} = live(conn)

      assert phone() |> get("/pair/#{code}") |> html_response(200) =~ "ha-auth-approve"
      assert phone() |> post("/pair/#{code}") |> html_response(200) =~ "ha-auth-approved"

      assert_redirect(view, "/auth/pair/finish")
      conn = conn |> recycle() |> get("/auth/pair/finish")
      assert redirected_to(conn) == "/?room=kitchen"
      assert get_session(conn, "ha_auth_user")["id"] == "u1"
    end

    test "approving needs a signed-in phone", %{conn: conn} do
      {conn, _} = login_page(conn)
      code = get_session(conn, "ha_auth_pair_code")
      assert redirected_to(get(build_conn(), "/pair/#{code}")) == "/login"
      assert Pairings.pending?(code)
    end

    test "a code works once", %{conn: conn} do
      {conn, _} = login_page(conn)
      code = get_session(conn, "ha_auth_pair_code")
      assert phone() |> post("/pair/#{code}") |> html_response(200) =~ "ha-auth-approved"
      assert phone() |> post("/pair/#{code}") |> html_response(200) =~ "ha-auth-expired"
      assert phone() |> get("/pair/#{code}") |> html_response(200) =~ "ha-auth-expired"
    end

    test "only the browser holding the code is signed in", %{conn: conn} do
      {other, _} = login_page(build_conn())

      :ok =
        Pairings.approve(get_session(other, "ha_auth_pair_code"), %{"id" => "u1", "admin" => true})

      {conn, _} = login_page(conn)

      conn = conn |> recycle() |> get("/auth/pair/finish")
      assert redirected_to(conn) == "/login"
      assert get_session(conn, "ha_auth_user") == nil
    end
  end

  describe "Kiosk Satellite" do
    setup do
      put_ha_auth_env(:kiosk, true)
    end

    defp dismiss(id, user_id) do
      Events.handle_event(%{
        "event_type" => "call_service",
        "data" => %{
          "domain" => "persistent_notification",
          "service" => "dismiss",
          "service_data" => %{"notification_id" => id}
        },
        "context" => %{"user_id" => user_id}
      })
    end

    defp kiosk_login(conn) do
      {conn, html} = login_page(conn)
      [_, id] = Regex.run(~r/data-notification="([^"]+)"/, html)
      {conn, id}
    end

    test "offered only with kiosk: true", %{conn: conn} do
      put_ha_auth_env(:kiosk, false)
      {_conn, html} = login_page(conn)
      refute html =~ "ha-auth-kiosk"
    end

    test "the page carries the session's nonce", %{conn: conn} do
      {conn, id} = kiosk_login(conn)
      assert id == KioskSignIn.notification_prefix() <> get_session(conn, "ha_auth_kiosk_nonce")
    end

    test "signs in whoever HA says dismissed the notification", %{conn: conn} do
      conn = get(conn, "/?room=kitchen")
      {conn, id} = kiosk_login(recycle(conn))
      dismiss(id, "u1")

      conn = conn |> recycle() |> get("/auth/kiosk")
      assert redirected_to(conn) == "/?room=kitchen"

      assert get_session(conn, "ha_auth_user") == %{
               "id" => "u1",
               "name" => "Selump",
               "admin" => true
             }
    end

    test "an event arriving while the request waits still counts", %{conn: conn} do
      {conn, id} = kiosk_login(conn)
      Task.start(fn -> Process.sleep(50) && dismiss(id, "u1") end)

      conn = conn |> recycle() |> get("/auth/kiosk")
      assert get_session(conn, "ha_auth_user")["id"] == "u1"
    end

    test "the kiosk's HA user must be allowed", %{conn: conn} do
      {conn, id} = kiosk_login(conn)
      dismiss(id, "u2")

      conn = conn |> recycle() |> get("/auth/kiosk")
      assert get_session(conn, "ha_auth_user") == nil
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "isn't allowed"
    end

    test "another session's nonce doesn't sign this one in", %{conn: conn} do
      {_other, id} = kiosk_login(build_conn())
      dismiss(id, "u1")
      {conn, _id} = kiosk_login(conn)

      conn = conn |> recycle() |> get("/auth/kiosk")
      assert get_session(conn, "ha_auth_user") == nil
    end

    test "not offered again right after a failure", %{conn: conn} do
      conn = get(conn, "/auth/kiosk")
      {_conn, html} = login_page(recycle(conn))
      refute html =~ "ha-auth-kiosk"
      assert html =~ "ha-auth-error"
    end
  end
end
