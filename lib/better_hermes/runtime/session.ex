defmodule BetterHermes.Runtime.Session do
  @moduledoc """
  A single Better Hermes task run.

  This process deliberately mirrors the me6 eval/action-pair idea at the
  hackathon-demo level: it owns intent, delegates to specialized workers, gates
  side-effectful tools behind approvals, and emits a structured trace.
  """

  use GenServer, restart: :temporary

  alias BetterHermes.Integrations.{GoogleCalendar, Registry, Scheduler, Serper}
  alias BetterHermes.Trace

  @agent_specs [
    {"browser", "Browser agent", "playwright", "Browses pages, clicks controls, and observes the web."},
    {"research", "Research agent", "serper", "Finds live evidence and source snippets."},
    {"analyst", "Evidence analyst", "native", "Ranks evidence, risks, and useful next steps."},
    {"calendar", "Calendar agent", "google_api", "Prepares and creates Google Calendar events."},
    {"scheduler", "Scheduler agent", "scheduler", "Creates cron-like in-app reminders."},
    {"synthesizer", "Pitch synthesizer", "native", "Turns the work into a pitch slide outline."}
  ]

  def start_link(%{"session_id" => session_id} = params) do
    GenServer.start_link(__MODULE__, params, name: via(session_id))
  end

  def approve(session_id, approval_id) do
    GenServer.cast(via(session_id), {:approve, approval_id})
  end

  def reject(session_id, approval_id) do
    GenServer.cast(via(session_id), {:reject, approval_id})
  end

  defp via(session_id), do: {:via, Registry, {BetterHermes.Runtime.Registry, session_id}}

  @impl true
  def init(params) do
    state = %{
      session_id: params["session_id"],
      topic: blank_to_default(params["topic"], "Research useful AI events near UQ"),
      audience: blank_to_default(params["audience"], "hackathon judges"),
      constraints: blank_to_default(params["constraints"], "Prefer credible sources and safe actions."),
      approvals: %{},
      search_results: [],
      notes: [],
      calendar_event: nil
    }

    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    Trace.emit(state.session_id, "job_started", %{
      "summary" => state.topic,
      "status" => "running",
      "integrations" => Registry.catalog()
    })

    for {id, label, backend, summary} <- @agent_specs do
      Trace.emit(state.session_id, "agent_spawned", %{
        "agent_id" => id,
        "label" => label,
        "backend" => backend,
        "status" => "idle",
        "summary" => summary,
        "parent_id" => "root"
      })
    end

    step(250, :browser_started)
    {:noreply, state}
  end

  def handle_info(:browser_started, state) do
    Trace.emit(state.session_id, "agent_status_changed", %{
      "agent_id" => "browser",
      "status" => "running",
      "summary" => "Opening a supervised browser workspace."
    })

    Trace.emit(state.session_id, "tool_started", %{
      "agent_id" => "browser",
      "tool_id" => "browser.playwright",
      "backend" => "playwright",
      "summary" => "Navigate, click, inspect DOM, and stream screenshots when Playwright is configured."
    })

    step(600, :search_started)
    {:noreply, state}
  end

  def handle_info(:search_started, state) do
    Trace.emit(state.session_id, "message_sent", %{
      "from_agent_id" => "browser",
      "to_agent_id" => "research",
      "summary" => "Need live sources for #{state.topic}."
    })

    Trace.emit(state.session_id, "agent_status_changed", %{
      "agent_id" => "research",
      "status" => "running",
      "summary" => "Querying Serper for current web evidence."
    })

    results =
      case Serper.search(state.topic) do
        {:ok, results} ->
          results

        {:error, reason} ->
          fallback_results(reason, state.topic)
      end

    for result <- results do
      Trace.emit(state.session_id, "tool_observation", %{
        "agent_id" => "research",
        "tool_id" => "search.serper",
        "status" => "observed",
        "summary" => result["title"],
        "payload" => result
      })
    end

    step(700, :analysis_started)
    {:noreply, %{state | search_results: results}}
  end

  def handle_info(:analysis_started, state) do
    Trace.emit(state.session_id, "message_sent", %{
      "from_agent_id" => "research",
      "to_agent_id" => "analyst",
      "summary" => "Passing #{length(state.search_results)} normalized source observations."
    })

    Trace.emit(state.session_id, "agent_status_changed", %{
      "agent_id" => "analyst",
      "status" => "running",
      "summary" => "Checking usefulness, source quality, and risks."
    })

    notes = [
      "Use live evidence, but keep the assistant's write actions approval-gated.",
      "The core differentiator is visible delegation plus real integrations.",
      "Apache Camel is optional per integration; native adapters stay fast for hackathon work."
    ]

    for note <- notes do
      Trace.emit(state.session_id, "agent_note", %{
        "agent_id" => "analyst",
        "status" => "running",
        "summary" => note
      })
    end

    step(700, :calendar_approval)
    {:noreply, %{state | notes: notes}}
  end

  def handle_info(:calendar_approval, state) do
    event = GoogleCalendar.proposed_event(state.topic, state.audience)
    approval_id = Trace.unique_id("appr")

    Trace.emit(state.session_id, "agent_status_changed", %{
      "agent_id" => "calendar",
      "status" => "waiting_for_approval",
      "summary" => "Prepared a calendar write."
    })

    Trace.emit(state.session_id, "approval_required", %{
      "approval_id" => approval_id,
      "agent_id" => "calendar",
      "tool_id" => "calendar.google",
      "action" => "create_event",
      "summary" => "Approve creating a Google Calendar event for the selected assistant action.",
      "payload" => event
    })

    {:noreply, %{state | approvals: Map.put(state.approvals, approval_id, {:calendar, event})}}
  end

  def handle_info(:scheduler_approval, state) do
    approval_id = Trace.unique_id("appr")
    reminder = %{"title" => "Follow up on #{state.topic}", "delay_ms" => 30_000}

    Trace.emit(state.session_id, "agent_status_changed", %{
      "agent_id" => "scheduler",
      "status" => "waiting_for_approval",
      "summary" => "Prepared an in-app scheduled reminder."
    })

    Trace.emit(state.session_id, "approval_required", %{
      "approval_id" => approval_id,
      "agent_id" => "scheduler",
      "tool_id" => "scheduler.local",
      "action" => "create_reminder",
      "summary" => "Approve creating an in-app reminder.",
      "payload" => reminder
    })

    {:noreply, %{state | approvals: Map.put(state.approvals, approval_id, {:scheduler, reminder})}}
  end

  def handle_info(:synthesize, state) do
    Trace.emit(state.session_id, "agent_status_changed", %{
      "agent_id" => "synthesizer",
      "status" => "running",
      "summary" => "Creating pitch slide outline."
    })

    outline = pitch_outline(state)

    Trace.emit(state.session_id, "job_completed", %{
      "agent_id" => "synthesizer",
      "status" => "completed",
      "summary" => "Pitch outline ready.",
      "payload" => %{"outline" => outline}
    })

    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:approve, approval_id}, state) do
    case Map.fetch(state.approvals, approval_id) do
      {:ok, {:calendar, event}} ->
        result = GoogleCalendar.create_event(event)

        Trace.emit(state.session_id, "tool_completed", %{
          "approval_id" => approval_id,
          "agent_id" => "calendar",
          "tool_id" => "calendar.google",
          "status" => status_for(result),
          "summary" => summary_for(result, "Calendar event handled."),
          "payload" => payload_for(result)
        })

        step(400, :scheduler_approval)
        {:noreply, %{state | approvals: Map.delete(state.approvals, approval_id), calendar_event: event}}

      {:ok, {:scheduler, reminder}} ->
        {:ok, job} = Scheduler.schedule(reminder["title"], reminder["delay_ms"])

        Trace.emit(state.session_id, "tool_completed", %{
          "approval_id" => approval_id,
          "agent_id" => "scheduler",
          "tool_id" => "scheduler.local",
          "status" => "completed",
          "summary" => "Scheduled local reminder #{job.id}.",
          "payload" => Map.from_struct(job)
        })

        step(500, :synthesize)
        {:noreply, %{state | approvals: Map.delete(state.approvals, approval_id)}}

      :error ->
        {:noreply, state}
    end
  end

  def handle_cast({:reject, approval_id}, state) do
    Trace.emit(state.session_id, "tool_completed", %{
      "approval_id" => approval_id,
      "status" => "rejected",
      "summary" => "User rejected side-effectful action."
    })

    next = if Enum.empty?(Map.delete(state.approvals, approval_id)), do: :synthesize, else: :noop
    if next != :noop, do: step(300, next)
    {:noreply, %{state | approvals: Map.delete(state.approvals, approval_id)}}
  end

  defp step(delay, msg), do: Process.send_after(self(), msg, delay)

  defp blank_to_default(value, default) when value in [nil, ""], do: default
  defp blank_to_default(value, _default), do: value

  defp fallback_results(reason, topic) do
    [
      %{
        "title" => "Serper unavailable: #{inspect(reason)}",
        "url" => "https://serper.dev/",
        "snippet" => "Configure SERPER_API_KEY for live web search. The runtime continues so the delegation demo remains visible.",
        "query" => topic,
        "source" => "fallback"
      }
    ]
  end

  defp status_for({:ok, _}), do: "completed"
  defp status_for({:error, _}), do: "failed"

  defp summary_for({:ok, payload}, _fallback), do: payload["summary"] || "Completed."
  defp summary_for({:error, reason}, fallback), do: "#{fallback} #{inspect(reason)}"

  defp payload_for({:ok, payload}), do: payload
  defp payload_for({:error, reason}), do: %{"error" => inspect(reason)}

  defp pitch_outline(state) do
    [
      %{"slide" => "Title", "points" => ["Better Hermes", "A visible, integration-capable personal assistant runtime"]},
      %{"slide" => "Problem", "points" => ["Assistants hide their work", "Integrations are brittle", "Users need control over side effects"]},
      %{"slide" => "Insight", "points" => Enum.take(state.notes, 3)},
      %{"slide" => "Solution", "points" => ["me6-style persistent agents", "Live 3D trace graph", "Approval-gated tools"]},
      %{"slide" => "Integrations", "points" => ["Playwright browser", "Serper search", "Google Calendar OAuth", "Local scheduler", "Optional Camel bridge"]},
      %{"slide" => "Demo", "points" => ["Watch agents spawn", "Approve calendar/scheduler writes", "Receive a final delegated result"]},
      %{"slide" => "Next", "points" => ["Attach real me6 eval/action pairs", "Run tools inside Flarenv workspaces", "Expand the Camel-backed connector catalog"]}
    ]
  end
end
