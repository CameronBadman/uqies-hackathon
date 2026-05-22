defmodule BetterHermesWeb.HermesChannelTest do
  use BetterHermesWeb.ChannelCase, async: false

  test "starts a delegated session and streams trace events" do
    {:ok, _, lobby} =
      BetterHermesWeb.UserSocket
      |> socket("user:demo", %{})
      |> subscribe_and_join(BetterHermesWeb.HermesChannel, "hermes:lobby")

    ref = push(lobby, "start_research", %{"topic" => "agent delegation demo"})
    assert_reply ref, :ok, %{session_id: session_id}

    {:ok, _, _trace} =
      BetterHermesWeb.UserSocket
      |> socket("user:demo", %{})
      |> subscribe_and_join(BetterHermesWeb.TraceChannel, "trace:#{session_id}")

    assert_push "trace_event", %{"type" => "job_started"}, 1_000
    assert_push "trace_event", %{"type" => "agent_spawned", "agent_id" => "browser"}, 1_000
  end
end
