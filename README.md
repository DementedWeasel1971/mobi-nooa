# mobi-nooa

**Mobile Object-Oriented Agents** — a faithful Dart/Kotlin adaptation of NVIDIA's
NOOA (*labs-OO-Agents*, arXiv:2607.20709), built for on-device and mobile-first
agentic AI applications.

This repository is set up as an **AI-native development repo**: it is designed to
be built collaboratively with AI coding agents (GitHub Copilot, Claude, etc.) using
a "vibe coding" workflow — clear specs, small verifiable steps, and durable
context files that any agent can pick up cold.

## Modules

| Module | Language | Purpose |
|---|---|---|
| [`mobi_nooa_core`](mobi_nooa_core/) | Dart | Platform-agnostic agent engine: agent base class, object heap, CodeAct execution, programmable loop, model clients, harness APIs, tracing. |
| [`android_mobi_nooa`](android_mobi_nooa/) | Kotlin (Android library) | Android integration layer exposing native device capabilities (filesystem, network, sensors) as harnesses callable by agents. |

## Start here

If you are an AI agent or a new contributor, read these in order:

1. **[AGENTS.md](AGENTS.md)** — how to work in this repo (build/test commands, conventions, guardrails).
2. **[DESIGN.md](DESIGN.md)** — architecture, NOOA principles, module boundaries, and data flow.
3. **[docs/decisions/](docs/decisions/)** — Architecture Decision Records (ADRs) explaining *why*, not just *what*.
4. **[.github/copilot-instructions.md](.github/copilot-instructions.md)** — repo-wide custom instructions consumed automatically by GitHub Copilot.

## Quick start

```powershell
# Dart core engine
cd mobi_nooa_core
dart pub get
dart test

# Android library
cd android_mobi_nooa
./gradlew build
```

## Status

Early-stage / actively scaffolded via AI pair-programming. See `docs/decisions/`
for the current state of architectural decisions and `AGENTS.md` for open
conventions that are still being established.
