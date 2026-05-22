defmodule BetterHermes.Integrations.Scheduler do
  @moduledoc """
  Small in-app scheduler used as the cron-like integration for the demo.
  """

  use GenServer

  defmodule Job do
    @derive Jason.Encoder
    defstruct [:id, :title, :delay_ms, :status, :created_at]
  end

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def schedule(title, delay_ms) when is_binary(title) and is_integer(delay_ms) do
    GenServer.call(__MODULE__, {:schedule, title, delay_ms})
  end

  def list, do: GenServer.call(__MODULE__, :list)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:schedule, title, delay_ms}, _from, state) do
    id = BetterHermes.Trace.unique_id("job")
    job = %Job{id: id, title: title, delay_ms: delay_ms, status: "scheduled", created_at: DateTime.utc_now()}
    Process.send_after(self(), {:fire, id}, delay_ms)
    {:reply, {:ok, job}, Map.put(state, id, job)}
  end

  def handle_call(:list, _from, state), do: {:reply, Map.values(state), state}

  @impl true
  def handle_info({:fire, id}, state) do
    updated = update_in(state, [id], fn
      nil -> nil
      job -> %{job | status: "fired"}
    end)

    {:noreply, updated}
  end
end
