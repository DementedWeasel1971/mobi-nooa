# GitHub Copilot custom instructions

> Full contributor/agent guide: see `AGENTS.md` and `DESIGN.md` at the repo
> root. This file is the entry point Copilot loads automatically for every
> chat, review, and coding-agent session in this repository.

## Project summary

mobi-nooa is a Dart/Kotlin implementation of NVIDIA's NOOA (Object-Oriented
Agents) framework fused with DeepSeek Harness's plugin-first architecture,
built for mobile/on-device agentic AI. Two primary modules:

- `mobi_nooa_core/` — platform-agnostic Dart engine: 5 reference agents
  (`AutonomousDeviceAgent`, `DataAnalystAgent`, `AutonomousCodingAgent`,
  `BenchAgent`, `GeneralMobileAgent`), object heap with pass-by-reference handles
  (`#ref_xxx`), CodeAct sandboxed evaluator, programmable loop, pluggable execution
  strategies (ReAct, CodeAct, Plan-and-Solve, Self-Reflection), two-way procedural
  skills (`nooa-skills`), model clients (DeepSeek-R1/V3, Gemini, Claude, OpenAI,
  Ollama, Nvidia NIM, OnDevice/llama.cpp), harnesses (filesystem, network, device,
  memory, SQLite, MCP, skills), coding tools (shell/file-editor/code-search),
  cognitive long-term memory (ACT-R activation, owner-gated scoping), SQLite-backed
  checkpoint storage, tiered permission policy engine (`PermissionManager`),
  plugin-first service seam (`AgentPlugin`/`PluginRegistry`), append-only session
  event logs with time-travel replay & forking (`SessionEventLog`), adaptive
  on-device resource governor (`nooa-governor`), AST security guardrails,
  benchmarking suite (SWE-bench & Mobile-Bench), and tracing.
- `android_mobi_nooa/` — Android/Kotlin library bridging into the Dart core
  via a headless Flutter engine + `MethodChannel` (`MobiNooaBridge.kt`,
  see ADR 0007); `MobiNooaService` (foreground non-killable loops) and
  `MobiNooaWorker` (WorkManager scheduled tasks); `mobi_nooa_bridge/` is the
  thin, UI-less Flutter shim that wraps `mobi_nooa_core`'s `AgentBridgeDispatcher`.

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
- New plugins implement `AgentPlugin` (`lib/src/plugin/`) and register via
  `PluginRegistry` (see `.github/skills/add-nooa-plugin/SKILL.md`).
- Sensitive operations on mobile must be evaluated via `PermissionManager`
  and respect `PermissionPolicy`.
- New coding tools build on an existing harness rather than calling
  `dart:io` directly; new execution strategies implement `ExecutionStrategy`
  rather than adding branches to `AgentLoop`.
- Any code path executing an LLM-authored snippet must run it through
  `AstGuardrails.validate` before the sandboxed evaluator.
- Long-term memory access must go through `OwnerGatedMemoryScope`, never a
  raw `ownerId` against the shared `CognitiveMemoryStore`.
- Checkpoint/resume persistence goes through `AgentCheckpoint` +
  `StateStorageManager`, not ad-hoc serialization.
- Adopt a strict Test-Driven Development (TDD) approach (Red -> Green -> Refactor):
  write or update unit tests in `mobi_nooa_core/test/` or `android_mobi_nooa/src/test/`
  before implementing new agents, harnesses, strategies, or Kotlin repositories.
  Use `MockModelClient` for deterministic LLM agent loop testing.
- After editing Dart code, run `dart analyze` and `dart test --exclude-tags live`
  in `mobi_nooa_core/`. After editing Kotlin/Gradle code, run `./gradlew build`
  in `android_mobi_nooa/`.
- Architecturally significant changes need an ADR in `docs/decisions/` and a
  `DESIGN.md` update.
- Never commit secrets, API keys, or `local.properties`.

For full detail (build commands, examples, guardrails, deployment workflows, UI design),
read `AGENTS.md`, `.github/skills/deploy-mobi-nooa/SKILL.md`, and `.github/skills/design-mobi-nooa-ui/SKILL.md`.
