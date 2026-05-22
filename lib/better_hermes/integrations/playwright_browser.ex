defmodule BetterHermes.Integrations.PlaywrightBrowser do
  @moduledoc """
  Playwright integration boundary.

  The Elixir runtime emits browser-agent trace events. This module is ready to
  call a Node Playwright probe when assets/playwright_probe.mjs and the
  playwright package are installed.
  """

  def observe(url) when is_binary(url) do
    script = Path.expand("../../../assets/playwright_probe.mjs", __DIR__)

    if File.exists?(script) do
      case System.cmd("node", [script, url], stderr_to_stdout: true) do
        {json, 0} -> Jason.decode(json)
        {output, status} -> {:error, {:playwright_failed, status, output}}
      end
    else
      {:ok,
       %{
         "url" => url,
         "title" => "Playwright probe not installed",
         "summary" => "Browser integration boundary is present; install Playwright to execute live browser actions."
       }}
    end
  end
end
