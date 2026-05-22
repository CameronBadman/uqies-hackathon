defmodule BetterHermes.Integrations.Serper do
  @moduledoc """
  Minimal Serper search adapter using OTP's built-in HTTP client.
  """

  @endpoint ~c"https://google.serper.dev/search"

  def search(query) when is_binary(query) do
    with {:ok, key} <- api_key(),
         {:ok, response} <- post(key, query),
         {:ok, decoded} <- Jason.decode(response) do
      {:ok, normalize(decoded, query)}
    end
  end

  def normalize(decoded, query) do
    decoded
    |> Map.get("organic", [])
    |> Enum.take(5)
    |> Enum.map(fn item ->
      %{
        "title" => item["title"] || "Untitled result",
        "url" => item["link"] || item["url"] || "",
        "snippet" => item["snippet"] || "",
        "query" => query,
        "source" => "serper"
      }
    end)
  end

  defp api_key do
    case System.get_env("SERPER_API_KEY") do
      nil -> {:error, :missing_search_api_key}
      "" -> {:error, :missing_search_api_key}
      key -> {:ok, key}
    end
  end

  defp post(key, query) do
    body = Jason.encode!(%{q: query})
    headers = [{~c"X-API-KEY", String.to_charlist(key)}, {~c"Content-Type", ~c"application/json"}]
    request = {@endpoint, headers, ~c"application/json", body}

    case :httpc.request(:post, request, [], body_format: :binary) do
      {:ok, {{_, status, _}, _headers, response}} when status in 200..299 -> {:ok, response}
      {:ok, {{_, status, _}, _headers, response}} -> {:error, {:http_status, status, response}}
      {:error, reason} -> {:error, reason}
    end
  end
end
