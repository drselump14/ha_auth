defmodule HaAuth.KioskSignIn do
  @moduledoc """
  Sign-in without a button on Kiosk Satellite tablets.

  Kiosk Satellite gives custom pages its HA connection
  (`window.kioskSatellite.ha`, "Share Home Assistant connection" on) but
  never the token. So the login page proves who it is through HA itself:
  it calls the no-op `persistent_notification.dismiss` with
  `notification_id: "ha_auth_sign_in_<nonce>"`, the nonce being in its
  session. HA fires `call_service` with the caller's `context.user_id`;
  `HaAuth.HA.Events` hands that to `dismissed/2`, and the `/auth/kiosk`
  request picks it up with `await/2`.

  The user id comes from HA, not the page, so a page can only sign in as
  the HA user whose credential made the call. Entries live 60 seconds and
  are taken once.
  """
  use GenServer

  @prefix "ha_auth_sign_in_"
  @ttl_ms 60_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def notification_prefix, do: @prefix

  @doc "`user_id` dismissed notification `id`: a sign-in when it carries our prefix."
  def dismissed(@prefix <> nonce, user_id) when nonce != "" do
    GenServer.cast(__MODULE__, {:record, nonce, user_id})
    Phoenix.PubSub.broadcast(HaAuth.PubSub, topic(nonce), {:ha_auth_kiosk, user_id})
  end

  def dismissed(_id, _user_id), do: :ignore

  @doc "The HA user id that confirmed `nonce`, waiting up to `timeout` ms."
  def await(nonce, timeout) when is_binary(nonce) do
    # Subscribe before looking, so an event landing in between isn't missed.
    Phoenix.PubSub.subscribe(HaAuth.PubSub, topic(nonce))

    result =
      case GenServer.call(__MODULE__, {:take, nonce}) do
        {:ok, user_id} ->
          {:ok, user_id}

        :error ->
          receive do
            {:ha_auth_kiosk, user_id} ->
              GenServer.call(__MODULE__, {:take, nonce})
              {:ok, user_id}
          after
            timeout -> {:error, :timeout}
          end
      end

    Phoenix.PubSub.unsubscribe(HaAuth.PubSub, topic(nonce))
    result
  end

  defp topic(nonce), do: "ha_auth:kiosk:" <> nonce

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:record, nonce, user_id}, state) do
    now = System.monotonic_time(:millisecond)

    {:noreply,
     state
     |> Map.reject(fn {_nonce, {_user, at}} -> now - at > @ttl_ms end)
     |> Map.put(nonce, {user_id, now})}
  end

  @impl true
  def handle_call({:take, nonce}, _from, state) do
    now = System.monotonic_time(:millisecond)

    case Map.pop(state, nonce) do
      {{user_id, at}, rest} when now - at <= @ttl_ms -> {:reply, {:ok, user_id}, rest}
      {_, rest} -> {:reply, :error, rest}
    end
  end
end
