defmodule BetterHermes.Integrations.CamelBridge do
  @moduledoc """
  Optional Apache Camel bridge contract.

  This keeps Camel available per integration without making the JVM route engine
  the core Better Hermes runtime.
  """

  def enabled?, do: System.get_env("CAMEL_BRIDGE_URL") not in [nil, ""]

  def route(component, payload) when is_binary(component) and is_map(payload) do
    if enabled?() do
      {:error, :camel_bridge_http_not_implemented_yet}
    else
      {:error, :camel_bridge_disabled}
    end
  end
end
