# Better Hermes

Better Hermes is a UQIES Build Anything Hackathon 2026 prototype for a visible,
integration-capable personal assistant runtime.

It combines:

- A Phoenix/Elixir OTP backend for me6-style delegated agents.
- A Three.js live graph that shows agents spawning, messaging, using tools, and waiting for approval.
- Pluggable integrations for Playwright browser work, Serper search, Google Calendar OAuth, local scheduler jobs, and an optional Apache Camel bridge.
- Approval-gated write actions for calendar writes, scheduled jobs, browser form submission, and future side-effecting Camel routes.

## Run

```sh
mix setup
mix phx.server
```

Open http://localhost:4000.

## Nix Dev Shell

```sh
/nix/var/nix/profiles/default/bin/nix develop
mix setup
npm install --prefix assets
mix phx.server
```

The dev shell includes Elixir 1.19 on Erlang/OTP 28, Node 22, Phoenix watcher
dependencies, `inotify-tools`, `watchman`, and Playwright browser binaries.

To run the browser agent against a real headless browser instead of the built-in
simulation:

```sh
BETTER_HERMES_ENABLE_PLAYWRIGHT=1 mix phx.server
```

## Optional Environment

```sh
export SERPER_API_KEY=...
export OPENAI_API_KEY=...
export OPENAI_MODEL=gpt-5-nano
export GOOGLE_CLIENT_ID=...
export GOOGLE_CLIENT_SECRET=...
export GOOGLE_REDIRECT_URI=http://localhost:4000/auth/google/callback
export GOOGLE_ACCESS_TOKEN=...
export CAMEL_BRIDGE_URL=...
```

`SERPER_API_KEY` enables live search. `OPENAI_API_KEY` enables model-backed
synthesis through the Responses API. The default model is `gpt-5-nano` to keep
demo costs low. Google OAuth can be started from the UI. `GOOGLE_ACCESS_TOKEN`
is useful for a quick local calendar smoke test.

## Architecture

- `BetterHermes.Runtime.Session` owns a single delegated user task.
- Agents emit structured trace events through Phoenix PubSub and Channels.
- The frontend consumes those events and updates the Three.js graph.
- Integration adapters live under `BetterHermes.Integrations`.
- Flarenv and me6 are treated as prior foundations for future deeper orchestration; this repo owns the hackathon-facing prototype.
