defmodule BetterHermes.Trace do
  @moduledoc """
  Structured event stream used by the backend runtime and the Three.js demo.
  """

  @pubsub BetterHermes.PubSub

  def topic(session_id), do: "trace:#{session_id}"

  def subscribe(session_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(session_id))
  end

  def emit(session_id, type, payload \\ %{}) when is_binary(session_id) and is_binary(type) do
    event =
      payload
      |> Map.new()
      |> Map.merge(%{
        "id" => unique_id("evt"),
        "session_id" => session_id,
        "type" => type,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      })

    Phoenix.PubSub.broadcast(@pubsub, topic(session_id), {:trace_event, event})
    event
  end

  def unique_id(prefix) do
    suffix =
      8
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    "#{prefix}_#{suffix}"
  end
end
