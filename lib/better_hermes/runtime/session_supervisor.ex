defmodule BetterHermes.Runtime.SessionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  alias BetterHermes.Runtime.Session

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_session(params) do
    session_id = BetterHermes.Trace.unique_id("ses")
    spec = {Session, Map.put(params, "session_id", session_id)}

    with {:ok, _pid} <- DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, session_id}
    end
  end

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)
end
