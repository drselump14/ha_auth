defmodule HaAuth.HA.Users do
  @moduledoc """
  HA's people (`config/auth/list`, admin-only and websocket-only, so it
  needs an admin `:token`). Used to name the user a kiosk signs in as.
  Swap in a stub with `config :ha_auth, :users_source, Mod`.
  """

  alias HaAuth.Config
  alias HaAuth.HA.OneShot

  @doc "The configured implementation (this module unless stubbed)."
  def impl, do: Config.get(:users_source, __MODULE__)

  @doc ~s|`{:ok, [%{"id", "name", "admin", "active"}]}`, without system users.|
  def users do
    if Config.token?() do
      with {:ok, users} when is_list(users) <-
             OneShot.call(Config.token(), %{type: "config/auth/list"}) do
        {:ok,
         for u <- users, not u["system_generated"] do
           %{
             "id" => u["id"],
             "name" => u["name"] || u["username"] || u["id"],
             "admin" => "system-admin" in (u["group_ids"] || []),
             "active" => u["is_active"] != false
           }
         end}
      end
    else
      {:error, :no_token}
    end
  end

  @doc ~s|The active user `id` as a session map `%{"id", "name", "admin"}`.|
  def find(id) do
    with {:ok, users} <- impl().users() do
      case Enum.find(users, &(&1["id"] == id and &1["active"])) do
        nil -> {:error, {:unknown_user, id}}
        u -> {:ok, Map.take(u, ["id", "name", "admin"])}
      end
    end
  end
end
