defmodule BetterHermesWeb.HermesChannel do
  use Phoenix.Channel

  alias BetterHermes.Runtime.SessionSupervisor

  @impl true
  def join("hermes:lobby", _payload, socket), do: {:ok, socket}

  @impl true
  def handle_in("start_research", payload, socket) do
    case SessionSupervisor.start_session(payload) do
      {:ok, session_id} ->
        {:reply, {:ok, %{session_id: session_id}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end
end
