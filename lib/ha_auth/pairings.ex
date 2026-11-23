defmodule HaAuth.Pairings do
  @moduledoc """
  QR sign-in. The login page holds a code (in its session) and shows
  `/pair/<code>` as a QR code; a signed-in phone opens it and approves,
  which hands the phone's user to that page. Codes live 10 minutes, are
  approved once and taken once. Approval is broadcast on `topic/1`, so the
  waiting page moves on at once.
  """
  use GenServer

  @ttl_ms 10 * 60_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def ttl_ms, do: @ttl_ms
  def topic(code), do: "ha_auth:pairing:" <> code

  @doc "A new pending code."
  def create do
    code = HaAuth.Session.random_id(16)
    GenServer.call(__MODULE__, {:create, code})
    code
  end

  @doc "Is `code` waiting for a phone?"
  def pending?(code) when is_binary(code), do: GenServer.call(__MODULE__, {:pending?, code})
  def pending?(_code), do: false

  @doc "`user` (from the phone's session) signs in the page holding `code`."
  def approve(code, user) when is_binary(code) do
    with :ok <- GenServer.call(__MODULE__, {:approve, code, user}) do
      Phoenix.PubSub.broadcast(HaAuth.PubSub, topic(code), {:ha_auth_paired, code})
      :ok
    end
  end

  @doc "The user who approved `code`, once; `:error` if not approved or expired."
  def take(code) when is_binary(code), do: GenServer.call(__MODULE__, {:take, code})
  def take(_code), do: :error

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:create, code}, _from, state),
    do: {:reply, :ok, state |> prune() |> Map.put(code, {:pending, now()})}

  def handle_call({:pending?, code}, _from, state),
    do: {:reply, match?({:pending, _}, live(state, code)), state}

  def handle_call({:approve, code, user}, _from, state) do
    case live(state, code) do
      {:pending, at} -> {:reply, :ok, Map.put(state, code, {{:approved, user}, at})}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:take, code}, _from, state) do
    case live(state, code) do
      {{:approved, user}, _at} -> {:reply, {:ok, user}, Map.delete(state, code)}
      _ -> {:reply, :error, state}
    end
  end

  defp live(state, code) do
    case Map.get(state, code) do
      {_status, at} = entry -> if now() - at <= @ttl_ms, do: entry
      nil -> nil
    end
  end

  defp prune(state), do: Map.reject(state, fn {_code, {_status, at}} -> now() - at > @ttl_ms end)
  defp now, do: System.monotonic_time(:millisecond)
end
