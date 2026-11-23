defmodule HaAuth.Web.LoginLive do
  @moduledoc """
  The login page, with all three ways in:

    1. Kiosk Satellite: an inline script calls the kiosk's shared HA
       connection when it exists, then goes to `/auth/kiosk`
    2. A QR code for `/pair/<code>`; when a phone approves it the page goes
       to `/auth/pair/finish`. It reloads for a new code when this one expires
    3. The "Sign in with Home Assistant" link

  The QR code and kiosk nonce come from this browser's session
  (`HaAuth.Plug`, `:login_codes`). The kiosk try is skipped right after a
  failed sign-in, so a misconfigured kiosk doesn't loop.
  """
  use Phoenix.LiveView

  import HaAuth.Web.Components

  alias HaAuth.{Config, KioskSignIn, Pairings}

  @impl true
  def mount(_params, session, socket) do
    code = session["ha_auth_pair_code"]

    if connected?(socket) do
      if Pairings.pending?(code) do
        Phoenix.PubSub.subscribe(HaAuth.PubSub, Pairings.topic(code))
        Process.send_after(self(), :refresh, Pairings.ttl_ms())
      else
        send(self(), :refresh)
      end
    end

    error = Phoenix.Flash.get(socket.assigns.flash, :error)
    nonce = session["ha_auth_kiosk_nonce"]

    {:ok,
     assign(socket,
       page_title: Config.app_name(),
       app_name: Config.app_name(),
       error: error,
       qr: qr_svg(socket, code),
       kiosk_id:
         Config.kiosk?() && is_nil(error) && nonce && KioskSignIn.notification_prefix() <> nonce
     )}
  end

  @impl true
  def handle_info({:ha_auth_paired, _code}, socket),
    do: {:noreply, redirect(socket, to: "/auth/pair/finish")}

  # A full reload, so the session gets a new code.
  def handle_info(:refresh, socket), do: {:noreply, redirect(socket, to: "/login")}

  defp qr_svg(_socket, nil), do: nil

  defp qr_svg(socket, code) do
    (socket.endpoint.url() <> "/pair/" <> code)
    |> EQRCode.encode()
    |> EQRCode.svg(width: 240, background_color: "#ffffff", color: "#000000")
    |> Phoenix.HTML.raw()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page>
      <h1>{@app_name}</h1>
      <p :if={@error} id="ha-auth-error" class="ha-auth-error">{@error}</p>

      <p :if={@kiosk_id} id="ha-auth-kiosk" data-notification={@kiosk_id} hidden>
        Signing in through Kiosk Satellite…
      </p>

      <div :if={@qr} id="ha-auth-qr">
        <div class="ha-auth-qr">{@qr}</div>
        <p>Scan with a phone that's signed in to approve this screen.</p>
      </div>

      <a id="ha-auth-sign-in" href="/auth/ha" class="ha-auth-btn">Sign in with Home Assistant</a>

      <script :if={@kiosk_id}>
        (() => {
          const el = document.getElementById("ha-auth-kiosk")
          const ha = window.kioskSatellite?.ha
          if (!el || !ha) return
          el.hidden = false
          ha.call({
            type: "call_service",
            domain: "persistent_notification",
            service: "dismiss",
            service_data: {notification_id: el.dataset.notification},
          })
            .then(() => window.location.assign("/auth/kiosk"))
            .catch(err => { el.textContent = `Kiosk sign-in unavailable (${err?.code || err}).` })
        })()
      </script>
    </.page>
    """
  end
end
