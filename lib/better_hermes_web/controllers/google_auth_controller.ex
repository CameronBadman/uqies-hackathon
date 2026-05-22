defmodule BetterHermesWeb.GoogleAuthController do
  use BetterHermesWeb, :controller

  alias BetterHermes.Integrations.GoogleCalendar

  def start(conn, _params) do
    redirect(conn, external: GoogleCalendar.oauth_url())
  end

  def callback(conn, %{"code" => code}) do
    case GoogleCalendar.exchange_code(code) do
      {:ok, _token_payload} ->
        conn
        |> put_flash(:info, "Google Calendar connected for this demo session.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Google Calendar OAuth failed: #{inspect(reason)}")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Google Calendar OAuth did not return a code.")
    |> redirect(to: ~p"/")
  end
end
