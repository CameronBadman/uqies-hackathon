defmodule BetterHermesWeb.UserSocket do
  use Phoenix.Socket

  channel "hermes:lobby", BetterHermesWeb.HermesChannel
  channel "trace:*", BetterHermesWeb.TraceChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
