defmodule BetterHermes.Integrations.SchedulerTest do
  use ExUnit.Case, async: false

  alias BetterHermes.Integrations.Scheduler

  test "schedules and fires an in-app reminder" do
    {:ok, job} = Scheduler.schedule("Follow up", 5)

    assert job.status == "scheduled"
    assert job.title == "Follow up"

    Process.sleep(15)

    assert Enum.any?(Scheduler.list(), &(&1.id == job.id and &1.status == "fired"))
  end
end
