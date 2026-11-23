defmodule HaAuth.HA.OneShot do
  @moduledoc """
  One websocket command to HA: connect, authenticate with `token`, send
  `command`, return its result, close. For what HA only offers over the
  websocket (`auth/current_user`, `config/auth/list`).
  """
  use WebSockex

  alias HaAuth.Config

  @timeout 10_000

  @spec call(String.t(), map) :: {:ok, term} | {:error, term}
  def call(token, command) do
    state = %{token: token, command: command, caller: self(), ref: make_ref()}

    case WebSockex.start(Config.websocket_url(), __MODULE__, state,
           ssl_options: Config.ssl_options()
         ) do
      {:ok, pid} -> await(pid, state.ref)
      {:error, reason} -> {:error, {:connect, reason}}
    end
  end

  defp await(pid, ref) do
    mon = Process.monitor(pid)

    receive do
      {^ref, result} ->
        Process.demonitor(mon, [:flush])
        result

      {:DOWN, ^mon, :process, ^pid, reason} ->
        {:error, {:closed, reason}}
    after
      @timeout ->
        Process.exit(pid, :kill)
        {:error, :timeout}
    end
  end

  @impl true
  def handle_frame({:text, text}, state), do: text |> Jason.decode!() |> handle_message(state)
  def handle_frame(_frame, state), do: {:ok, state}

  defp handle_message(%{"type" => "auth_required"}, state) do
    {:reply, {:text, Jason.encode!(%{type: "auth", access_token: state.token})}, state}
  end

  defp handle_message(%{"type" => "auth_ok"}, state) do
    {:reply, {:text, Jason.encode!(Map.put(state.command, :id, 1))}, state}
  end

  defp handle_message(%{"type" => "auth_invalid"}, state),
    do: reply({:error, :auth_invalid}, state)

  defp handle_message(%{"id" => 1, "type" => "result", "success" => true} = msg, state),
    do: reply({:ok, msg["result"]}, state)

  defp handle_message(%{"id" => 1, "type" => "result"} = msg, state),
    do: reply({:error, msg["error"]}, state)

  defp handle_message(_msg, state), do: {:ok, state}

  defp reply(result, state) do
    send(state.caller, {state.ref, result})
    {:close, state}
  end
end
