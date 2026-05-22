defmodule BetterHermes.Integrations.SerperTest do
  use ExUnit.Case, async: true

  alias BetterHermes.Integrations.Serper

  test "normalizes organic search results" do
    decoded = %{
      "organic" => [
        %{"title" => "One", "link" => "https://example.com/one", "snippet" => "First"},
        %{"title" => "Two", "link" => "https://example.com/two", "snippet" => "Second"}
      ]
    }

    assert [
             %{
               "title" => "One",
               "url" => "https://example.com/one",
               "snippet" => "First",
               "query" => "agent assistants",
               "source" => "serper"
             },
             %{"title" => "Two"}
           ] = Serper.normalize(decoded, "agent assistants")
  end

  test "search reports missing api key clearly" do
    previous = System.get_env("SERPER_API_KEY")
    System.delete_env("SERPER_API_KEY")

    assert {:error, :missing_search_api_key} = Serper.search("anything")

    if previous, do: System.put_env("SERPER_API_KEY", previous)
  end
end
