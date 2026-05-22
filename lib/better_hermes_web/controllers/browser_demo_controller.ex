defmodule BetterHermesWeb.BrowserDemoController do
  use BetterHermesWeb, :controller

  def show(conn, _params) do
    html(conn, """
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>Better Hermes Browser Target</title>
        <style>
          body { font-family: system-ui, sans-serif; background: #101314; color: #edf3ef; padding: 32px; }
          main { max-width: 720px; margin: 0 auto; border: 1px solid rgba(255,255,255,.14); border-radius: 10px; padding: 24px; background: #171c1d; }
          button { background: #79d6b5; border: 0; border-radius: 6px; padding: 12px 16px; font-weight: 700; color: #07110d; cursor: pointer; }
          #state { margin-top: 18px; color: #b9c7c0; }
        </style>
      </head>
      <body>
        <main>
          <h1>Browser agent target</h1>
          <p id="intent">The agent should click the action and observe the changed state.</p>
          <button id="demo-action" type="button">Run page action</button>
          <p id="state">waiting</p>
        </main>
        <script>
          document.getElementById("demo-action").addEventListener("click", () => {
            document.getElementById("state").textContent = "clicked by browser agent";
          });
        </script>
      </body>
    </html>
    """)
  end
end
