defmodule BetterHermes.Integrations.Registry do
  @moduledoc """
  Catalog of integration backends available to Better Hermes agents.
  """

  @catalog [
    %{
      id: "browser.playwright",
      label: "Playwright browser",
      backend: "playwright",
      capabilities: ["navigate", "click", "dom_observe", "screenshot"],
      side_effects: ["form_submit"]
    },
    %{
      id: "search.serper",
      label: "Serper web search",
      backend: "native",
      capabilities: ["web_search"],
      side_effects: []
    },
    %{
      id: "calendar.google",
      label: "Google Calendar",
      backend: "google_api",
      capabilities: ["oauth", "create_event"],
      side_effects: ["calendar_write"]
    },
    %{
      id: "scheduler.local",
      label: "Local scheduler",
      backend: "scheduler",
      capabilities: ["create_reminder", "cancel_reminder"],
      side_effects: ["scheduled_action"]
    },
    %{
      id: "camel.bridge",
      label: "Apache Camel bridge",
      backend: "camel_bridge",
      capabilities: ["route_request", "component_catalog"],
      side_effects: ["depends_on_route"],
      optional: true
    }
  ]

  def catalog, do: Enum.map(@catalog, &stringify/1)

  def get(id), do: Enum.find(catalog(), &(&1["id"] == id))

  def side_effecting?(id) do
    case get(id) do
      nil -> false
      integration -> integration["side_effects"] != []
    end
  end

  defp stringify(map) do
    for {key, value} <- map, into: %{}, do: {Atom.to_string(key), value}
  end
end
