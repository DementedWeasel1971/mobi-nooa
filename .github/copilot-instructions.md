# GitHub Copilot custom instructions

> Full contributor/agent guide: see `AGENTS.md` and `DESIGN.md` at the repo
> root. This file is the entry point Copilot loads automatically for every
> chat, review, and coding-agent session in this repository.

## Project summary

mobi-nooa is a Dart/Kotlin implementation of NVIDIA's NOOA (Object-Oriented
Agents) framework, built for mobile/on-device agentic AI. Two modules:

- `mobi_nooa_core/` — platform-agnostic Dart engine: agent core, object
  heap, CodeAct execution, programmable loop, pluggable execution
  strategies (ReAct, CodeAct, Plan-and-Solve, Self-Reflection), model
  clients, harnesses (filesystem, network, device, memory, SQLite, MCP),
  coding tools (shell/file-editor/code-search) powering `BenchAgent`,
  cognitive long-term memory (ACT-R activation, owner-gated scoping),
  SQLite-backed checkpoint storage, AST security guardrails for CodeAct,
  a benchmarking suite (SWE-bench/mobile), and tracing.
- `android_mobi_nooa/` — Android/Kotlin library bridging into the Dart core
  via a headless Flutter engine + `MethodChannel` (`MobiNooaBridge.kt`,
  see ADR 0007); `mobi_nooa_bridge/` is the thin, UI-less Flutter shim that
  wraps `mobi_nooa_core`'s `AgentBridgeDispatcher` on the Dart side.

## Conventions Copilot must follow

- Keep `mobi_nooa_core` free of any `flutter`/`dart:ui` dependency.
- Export new public Dart classes from `mobi_nooa_core/lib/mobi_nooa_core.dart`,
  grouped under the matching subsystem comment header.
- New agent state must go through `NooaAgent.setState`/`getState`, not raw
  instance fields.
- New platform-bridge actions must go through `AgentBridgeDispatcher`
  (`lib/src/bridge/`) — don't hand-roll a separate `MethodChannel` handler.
- Large/complex tool-call return values must be wrapped via
  `ObjectHeap.maybeWrap` (pass-by-reference), not returned inline.
- New model providers implement `ModelClient`; new device/tool capabilities
  implement the relevant `*Harness` interface and are named `*_harness.dart`
  (see `.github/skills/add-nooa-harness/SKILL.md`).
- New coding tools build on an existing harness rather than calling
  `dart:io` directly; new execution strategies implement `ExecutionStrategy`
  rather than adding branches to `AgentLoop`.
- Any code path executing an LLM-authored snippet must run it through
  `AstGuardrails.validate` before the sandboxed evaluator.
- Long-term memory access must go through `OwnerGatedMemoryScope`, never a
  raw `ownerId` against the shared `CognitiveMemoryStore`.
- Checkpoint/resume persistence goes through `AgentCheckpoint` +
  `StateStorageManager`, not ad-hoc serialization.
- Follow `package:lints/recommended` for Dart; standard Kotlin/Android style
  for the Gradle module.
- After editing Dart code, run `dart analyze` and `dart test` in
  `mobi_nooa_core/`. After editing Kotlin/Gradle code, run `./gradlew build`
  in `android_mobi_nooa/`.
- Architecturally significant changes need an ADR in `docs/decisions/` and a
  `DESIGN.md` update.
- Never commit secrets, API keys, or `local.properties`.

For full detail (build commands, examples, guardrails), read `AGENTS.md`.
