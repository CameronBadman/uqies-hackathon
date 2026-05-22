defmodule BetterHermes.Integrations.OpenAIResponsesTest do
  use ExUnit.Case, async: false

  alias BetterHermes.Integrations.OpenAIResponses

  test "uses a cheap model by default" do
    previous = System.get_env("OPENAI_MODEL")
    System.delete_env("OPENAI_MODEL")

    assert OpenAIResponses.model() == "gpt-5-nano"

    if previous, do: System.put_env("OPENAI_MODEL", previous)
  end

  test "reports unavailable without an API key" do
    previous = System.get_env("OPENAI_API_KEY")
    System.delete_env("OPENAI_API_KEY")

    refute OpenAIResponses.available?()
    assert :error = OpenAIResponses.pitch_outline(%{})

    if previous, do: System.put_env("OPENAI_API_KEY", previous)
  end
end
