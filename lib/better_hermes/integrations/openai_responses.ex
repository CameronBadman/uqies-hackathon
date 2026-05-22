defmodule BetterHermes.Integrations.OpenAIResponses do
  @moduledoc """
  Minimal OpenAI Responses API adapter.

  The runtime only calls this when OPENAI_API_KEY is configured. Without a key,
  Better Hermes emits a model-unavailable trace event and uses its deterministic
  hackathon fallback.
  """

  @endpoint ~c"https://api.openai.com/v1/responses"

  def available?, do: api_key() != :error

  def model, do: System.get_env("OPENAI_MODEL") || "gpt-5-nano"

  def pitch_outline(state) do
    with {:ok, key} <- api_key(),
         {:ok, response} <- request_outline(key, state),
         {:ok, outline} <- parse_outline(response) do
      {:ok, outline}
    end
  end

  defp api_key do
    case System.get_env("OPENAI_API_KEY") do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> :error
    end
  end

  defp request_outline(key, state) do
    body =
      Jason.encode!(%{
        "model" => model(),
        "instructions" =>
          "You are the Better Hermes synthesizer agent. Return only JSON with an outline array. Each outline item must have slide and points fields.",
        "input" => prompt(state),
        "max_output_tokens" => 1200,
        "reasoning" => %{"effort" => "low"},
        "text" => %{
          "verbosity" => "low",
          "format" => %{
            "type" => "json_schema",
            "name" => "pitch_outline",
            "strict" => true,
            "schema" => %{
              "type" => "object",
              "additionalProperties" => false,
              "required" => ["outline"],
              "properties" => %{
                "outline" => %{
                  "type" => "array",
                  "items" => %{
                    "type" => "object",
                    "additionalProperties" => false,
                    "required" => ["slide", "points"],
                    "properties" => %{
                      "slide" => %{"type" => "string"},
                      "points" => %{"type" => "array", "items" => %{"type" => "string"}}
                    }
                  }
                }
              }
            }
          }
        }
      })

    headers = [
      {~c"Authorization", ~c"Bearer #{key}"},
      {~c"Content-Type", ~c"application/json"}
    ]

    case :httpc.request(:post, {@endpoint, headers, ~c"application/json", body}, [],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _headers, response}} when status in 200..299 ->
        Jason.decode(response)

      {:ok, {{_, status, _}, _headers, response}} ->
        {:error, {:http_status, status, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prompt(state) do
    """
    Create a concise pitch slide outline for this delegated assistant run.

    Topic: #{state.topic}
    Audience: #{state.audience}
    Constraints: #{state.constraints}
    Analyst notes: #{Enum.join(state.notes, " | ")}
    Search results: #{Jason.encode!(state.search_results)}

    JSON shape:
    {"outline":[{"slide":"Title","points":["point one","point two"]}]}
    """
  end

  defp parse_outline(response) do
    response
    |> output_text()
    |> decode_outline()
  end

  defp output_text(%{"output_text" => text}) when is_binary(text), do: text

  defp output_text(%{"output" => output}) when is_list(output) do
    output
    |> Enum.flat_map(&Map.get(&1, "content", []))
    |> Enum.map(fn
      %{"type" => "output_text", "text" => text} -> text
      %{"text" => text} -> text
      _ -> ""
    end)
    |> Enum.join("\n")
  end

  defp output_text(_), do: ""

  defp decode_outline(text) do
    with {:ok, decoded} <- Jason.decode(text),
         outline when is_list(outline) <- decoded["outline"] do
      {:ok, outline}
    else
      _ -> {:error, :invalid_model_outline}
    end
  end
end
