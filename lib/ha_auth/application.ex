defmodule HaAuth.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [{Phoenix.PubSub, name: HaAuth.PubSub}, HaAuth.Pairings, HaAuth.KioskSignIn] ++
        events()

    Supervisor.start_link(children, strategy: :one_for_one, name: HaAuth.Supervisor)
  end

  # The HA listener only matters for Kiosk Satellite sign-in.
  defp events do
    if HaAuth.Config.kiosk?() and HaAuth.Config.token?() do
      [HaAuth.HA.Events]
    else
      if HaAuth.Config.kiosk?() do
        require Logger
        Logger.warning("HaAuth: kiosk: true but no :token; Kiosk Satellite sign-in is off")
      end

      []
    end
  end
end
