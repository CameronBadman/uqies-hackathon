defmodule BetterHermes.Integrations.GoogleCalendar do
  @moduledoc """
  Google Calendar integration.

  If an OAuth token is available in the in-memory credential store or
  GOOGLE_ACCESS_TOKEN, create_event/1 calls the real Google Calendar API.
  Otherwise it returns a clear OAuth-required payload for the UI/demo.
  """

  alias BetterHermes.Integrations.CredentialStore

  @calendar_endpoint ~c"https://www.googleapis.com/calendar/v3/calendars/primary/events"
  @token_endpoint ~c"https://oauth2.googleapis.com/token"

  def proposed_event(topic, audience) do
    starts_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
    ends_at = DateTime.add(starts_at, 1800, :second)

    %{
      "summary" => "Better Hermes follow-up: #{topic}",
      "description" =>
        "Created by Better Hermes for #{audience}. Approval-gated assistant write.",
      "start" => %{"dateTime" => DateTime.to_iso8601(starts_at)},
      "end" => %{"dateTime" => DateTime.to_iso8601(ends_at)}
    }
  end

  def create_event(event) do
    with {:ok, token} <- access_token(),
         {:ok, payload} <- post_event(token, event) do
      {:ok, Map.put(payload, "summary", "Created Google Calendar event.")}
    else
      {:error, :missing_google_oauth} ->
        {:error,
         %{
           reason: :missing_google_oauth,
           auth_url: oauth_url(),
           message: "Connect Google Calendar or set GOOGLE_ACCESS_TOKEN."
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def oauth_url do
    params =
      URI.encode_query(%{
        client_id: client_id() || "",
        redirect_uri: redirect_uri(),
        response_type: "code",
        scope: "https://www.googleapis.com/auth/calendar.events",
        access_type: "offline",
        prompt: "consent"
      })

    "https://accounts.google.com/o/oauth2/v2/auth?#{params}"
  end

  def exchange_code(code) when is_binary(code) do
    body =
      URI.encode_query(%{
        code: code,
        client_id: client_id() || "",
        client_secret: client_secret() || "",
        redirect_uri: redirect_uri(),
        grant_type: "authorization_code"
      })

    headers = [{~c"Content-Type", ~c"application/x-www-form-urlencoded"}]

    case :httpc.request(
           :post,
           {@token_endpoint, headers, ~c"application/x-www-form-urlencoded", body},
           [],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _headers, response}} when status in 200..299 ->
        with {:ok, decoded} <- Jason.decode(response),
             token when is_binary(token) <- decoded["access_token"] do
          CredentialStore.put(:google_access_token, token)
          {:ok, decoded}
        else
          _ -> {:error, :missing_access_token}
        end

      {:ok, {{_, status, _}, _headers, response}} ->
        {:error, {:http_status, status, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp access_token do
    token = CredentialStore.get(:google_access_token) || System.get_env("GOOGLE_ACCESS_TOKEN")
    if token in [nil, ""], do: {:error, :missing_google_oauth}, else: {:ok, token}
  end

  defp post_event(token, event) do
    body = Jason.encode!(event)

    headers = [
      {~c"Authorization", ~c"Bearer #{token}"},
      {~c"Content-Type", ~c"application/json"}
    ]

    case :httpc.request(:post, {@calendar_endpoint, headers, ~c"application/json", body}, [],
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

  defp client_id, do: System.get_env("GOOGLE_CLIENT_ID")
  defp client_secret, do: System.get_env("GOOGLE_CLIENT_SECRET")

  defp redirect_uri,
    do: System.get_env("GOOGLE_REDIRECT_URI") || "http://localhost:4000/auth/google/callback"
end
