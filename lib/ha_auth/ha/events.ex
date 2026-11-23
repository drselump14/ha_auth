defmodule HaAuth.HA.Events do
  @moduledoc """
  Websocket to HA, subscribed to `call_service`, for Kiosk Satellite
  sign-in: a `persistent_notification.dismiss` of an
  `ha_auth_sign_in_<nonce>` id goes to `HaAuth.KioskSignIn` with the HA
  user HA says made the call. Started only with `kiosk: true` and a token
  (admin, since other users' events are admin-only). Reconnects on drops.
  """
  use WebSockex
  require Logger

  alias HaAuth.{Config, KioskSignIn}

  @reconnect_ms 5_000

  def start_link(_opts) do
    WebSockex.start_link(Config.websocket_url(), __MODULE__, %{},
      name: __MODULE__,
      handle_initial_conn_failure: true,
      ssl_options: Config.ssl_options()
    )
  end

  @impl true
  def handle_frame({:text, text}, state), do: text |> Jason.decode!() |> handle_message(state)
  def handle_frame(_frame, state), do: {:ok, state}

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("HaAuth: HA websocket down: #{inspect(reason)}; retrying")
    Process.sleep(@reconnect_ms)
    {:reconnect, state}
  end

  defp handle_message(%{"type" => "auth_required"}, state) do
    {:reply, {:text, Jason.encode!(%{type: "auth", access_token: Config.token()})}, state}
  end

  defp handle_message(%{"type" => "auth_ok"}, state) do
    msg = %{id: 1, type: "subscribe_events", event_type: "call_service"}
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  defp handle_message(%{"type" => "auth_invalid", "message" => msg}, state) do
    Logger.error("HaAuth: HA refused the token: #{msg}")
    {:close, state}
  end

  defp handle_message(%{"type" => "result", "success" => false, "error" => error}, state) do
    Logger.warning("HaAuth: can't subscribe to call_service (admin token?): #{inspect(error)}")
    {:ok, state}
  end

  defp handle_message(%{"type" => "event", "event" => event}, state) do
    handle_event(event)
    {:ok, state}
  end

  defp handle_message(_msg, state), do: {:ok, state}

  @doc false
  def handle_event(%{
        "event_type" => "call_service",
        "data" => %{
          "domain" => "persistent_notification",
          "service" => "dismiss",
          "service_data" => %{"notification_id" => id}
        },
        "context" => %{"user_id" => user_id}
      })
      when is_binary(id) and is_binary(user_id) do
    KioskSignIn.dismissed(id, user_id)
  end

  def handle_event(_event), do: :ignore
end
