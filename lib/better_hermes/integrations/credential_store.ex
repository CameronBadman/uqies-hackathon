defmodule BetterHermes.Integrations.CredentialStore do
  @moduledoc false

  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: __MODULE__)
  def put(key, value), do: Agent.update(__MODULE__, &Map.put(&1, key, value))
  def get(key), do: Agent.get(__MODULE__, &Map.get(&1, key))
end
