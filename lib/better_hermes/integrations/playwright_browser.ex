defmodule BetterHermes.Integrations.PlaywrightBrowser do
  @moduledoc """
  Playwright integration boundary.

  The Elixir runtime emits browser-agent trace events. This module is ready to
  call a Node Playwright probe when assets/playwright_probe.mjs and the
  playwright package are installed.
  """

  def observe(url) when is_binary(url) do
    script = Path.expand("../../../assets/playwright_probe.mjs", __DIR__)

    if enabled?() and File.exists?(script) do
      case System.cmd("node", [script, url], stderr_to_stdout: true) do
        {json, 0} -> Jason.decode(json)
        {output, status} -> {:error, {:playwright_failed, status, output}}
      end
    else
      {:ok,
       %{
         "url" => url,
         "title" => "Playwright probe simulated",
         "summary" =>
           "Browser agent simulated navigation, click, DOM observation, and screenshot capture. Set BETTER_HERMES_ENABLE_PLAYWRIGHT=1 to run live.",
         "steps" => [
           "Navigate to demo target",
           "Click the primary action",
           "Observe changed DOM state",
           "Capture screenshot"
         ],
         "clicked" => true,
         "mode" => "simulated"
       }}
    end
  end

  defp enabled?, do: System.get_env("BETTER_HERMES_ENABLE_PLAYWRIGHT") in ["1", "true", "yes"]
end
