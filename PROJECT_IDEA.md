# Project Idea: Better Hermes

This project is for the UQIES Build Anything Hackathon 2026.

## Core Direction

Build "Better Hermes": an improved agent/workspace system that uses the user's existing work as the technical foundation.

## Existing Work To Build From

### Flarenv

Repository: https://github.com/CameronBadman/Flarenv

Flarenv is a Nix-based environment manager for agent workspaces. The existing repo describes:

- SSH-compatible session routing into agent workspaces
- btrfs-backed writable roots with snapshots and branches
- `systemd-nspawn` execution with cgroup limits and network policy
- A fixed read-only Nix toolset shared across environments
- Rust control-plane foundations, including workspace lifecycle types, storage and executor adapter traits, in-memory implementations for deterministic tests, host command builders, and event-driven runtime primitives

### me6

Repository: https://github.com/CameronBadman/me6

`me6` is an Elixir/OTP-first AI agent framework starter built around persistent `MrMe6` eval/action pairs. The existing repo describes:

- One long-lived eval process and one long-lived action process per pair
- Eval as the control plane for task intent, success criteria, retries, and completion checks
- Action as the execution plane for bounded execution turns
- Native tool invocation, tool registry, structured tool calls, and tool results
- Mailboxes and communication between agents
- Capability/path-prefix policies for tools, mailboxes, and directory access
- Pair manager support for parent/child agent pairs and lineage
- Planned next steps: LLM-backed action runner, event logging, real child-pair delegation with budget accounting, and durable task state/resumability

## Hackathon Framing

The project should be framed around turning these foundations into a coherent demoable product:

- `me6` provides the agent orchestration model.
- `Flarenv` provides isolated, reproducible, branchable workspaces for agent execution.
- "Better Hermes" should show why persistent agent pairs plus isolated workspaces are useful to real users.

## Constraints From Hackathon Rules

- Do not include pre-hackathon implementation as hackathon-created work unless permitted by organisers.
- Existing repos can be referenced as prior work/foundation, but new hackathon work should be clearly separated.
- Pitch deck must be submitted as `.pptx` by 3:00 PM on May 23, 2026.
- The idea and demo must stay respectful, safe, legal, and non-malicious.
