# AGENTS.md

Instructions for AI coding agents (GitHub Copilot, Claude, Copilot CLI, etc.)
working in the **mobi-nooa** repository. Read this before making changes.

## What this project is

mobi-nooa is a Dart/Kotlin port of NVIDIA's NOOA (Object-Oriented Agents)
framework for mobile/on-device agentic AI. See `DESIGN.md` for the full
architecture and the 6 NOOA principles this codebase implements.

- `mobi_nooa_core/` — pure Dart library, no Flutter/UI dependency. This is
  where almost all logic lives.
- `android_mobi_nooa/` — Android (Kotlin) library module that will bridge
  native device capabilities to the Dart core (via platform channels or FFI).

## Working conventions

- **Language/style**: Dart code follows `package:lints/recommended` (see
  `mobi_nooa_core/analysis_options.yaml` if present, otherwise default Dart
  style — 2-space indent, `lowerCamelCase` members, `UpperCamelCase` types).
  Kotlin/Gradle code follows standard Android/Kotlin conventions.
- **Public API surface**: All public exports go through
  `mobi_nooa_core/lib/mobi_nooa_core.dart`. If you add a new public class,
  export it there.
- **Docstrings double as prompts**: Per NOOA Principle 1, `NooaAgent` methods'
  doc comments and type annotations are used to build LLM tool-call prompts.
  Keep doc comments accurate and concise — they are not just documentation,
  they are runtime-visible contracts.
- **State goes through `setState`/`getState`**: Agents must not use ad-hoc
  instance fields for state the LLM needs to reason about; use the explicit
  `_state` map via `NooaAgent.setState`/`getState` (NOOA Principle 5).
- **Large objects go through the heap**: Don't return large blobs directly
  from tool calls — wrap them with `ObjectHeap.maybeWrap` so the LLM gets a
  pass-by-reference handle instead of a huge payload (NOOA Principle 2).
- **New model providers**: implement `ModelClient` (see
  `lib/src/models/model_client.dart`) and mirror the structure of an existing
  client (e.g. `openai_client.dart`) rather than inventing a new pattern.
- **New harness capabilities**: implement `HarnessApi` (see
  `lib/src/harness/harness_api.dart`) and follow the naming pattern
  `*_harness.dart`.

## Build, test, and validate

Run these from the relevant module directory (not repo root — there is no
root-level build tool yet).

```powershell
# Dart core
cd mobi_nooa_core
dart pub get          # install/update dependencies
dart analyze          # static analysis — must be clean before committing
dart test             # run unit tests

# Android library
cd android_mobi_nooa
./gradlew build       # compile + lint + unit tests
```

Always run `dart analyze` and `dart test` (or the equivalent Gradle task)
after modifying Dart or Kotlin source, and paste failing output back into
context rather than guessing at fixes.

## Guardrails

- Do not add a dependency on `flutter`/`dart:ui` to `mobi_nooa_core` — it must
  stay platform-agnostic and usable from plain Dart or server-side contexts.
- Do not commit secrets, API keys, or `local.properties`. Model provider API
  keys are supplied by the host app at runtime via `ModelClient` constructors.
- Do not bypass `AgentContext`/`ObjectHeap`/`Tracer` when adding new agent
  capabilities — every state mutation, tool call, and error should be
  observable through the existing tracing (`TraceEventType`) so agent runs
  stay debuggable.
- When a change affects architecture or a NOOA principle's implementation,
  add or update an ADR in `docs/decisions/` and update `DESIGN.md`.
- Prefer small, verifiable, single-purpose commits. If a task is ambiguous
  (e.g. which model provider to prioritize, which harness to build next),
  ask before proceeding rather than guessing.

## Where to look for examples

- Agent definition pattern: `mobi_nooa_core/lib/src/agent/nooa_agent.dart`
- Agentic loop / step execution: `mobi_nooa_core/lib/src/loop/agent_loop.dart`
- Adding a tool/action: `registerAction(...)` calls in a `NooaAgent` subclass
- Adding a model provider: `mobi_nooa_core/lib/src/models/*_client.dart`
- Adding a harness: `mobi_nooa_core/lib/src/harness/*_harness.dart`
