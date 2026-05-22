defmodule BetterHermes.Integrations.RegistryTest do
  use ExUnit.Case, async: true

  alias BetterHermes.Integrations.Registry

  test "catalog includes core native and optional integration backends" do
    ids = Registry.catalog() |> Enum.map(& &1["id"])

    assert "browser.playwright" in ids
    assert "search.serper" in ids
    assert "calendar.google" in ids
    assert "scheduler.local" in ids
    assert "camel.bridge" in ids
  end

  test "side effect metadata marks write integrations" do
    refute Registry.side_effecting?("search.serper")
    assert Registry.side_effecting?("calendar.google")
    assert Registry.side_effecting?("scheduler.local")
  end
end
