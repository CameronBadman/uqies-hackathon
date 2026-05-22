defmodule BetterHermesWeb.TraceChannel do
  use Phoenix.Channel

  alias BetterHermes.Runtime.Session
  alias BetterHermes.Trace

  @impl true
  def join("trace:" <> session_id, _payload, socket) do
    :ok = Trace.subscribe(session_id)
    {:ok, assign(socket, :session_id, session_id)}
  end

  @impl true
  def handle_info({:trace_event, event}, socket) do
    push(socket, "trace_event", event)
    {:noreply, socket}
  end

  @impl true
  def handle_in("approve", %{"approval_id" => approval_id}, socket) do
    Session.approve(socket.assigns.session_id, approval_id)
    {:reply, :ok, socket}
  end

  def handle_in("reject", %{"approval_id" => approval_id}, socket) do
    Session.reject(socket.assigns.session_id, approval_id)
    {:reply, :ok, socket}
  end
end
