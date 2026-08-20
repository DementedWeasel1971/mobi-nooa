# AGENTS.md

Instructions for AI coding agents (GitHub Copilot, Claude, Copilot CLI, etc.)
working in the **mobi-nooa** repository. Read this before making changes.

## What this project is

mobi-nooa is a Dart/Kotlin port of NVIDIA's NOOA (Object-Oriented Agents)
framework for mobile/on-device agentic AI. See `DESIGN.md` for the full
architecture and the 6 NOOA principles this codebase implements.

- `mobi_nooa_core/` — pure Dart library, no Flutter/UI dependency. This is
  where almost all logic lives: agent core, object heap, CodeAct engine,
  loop, execution strategies, model clients, harnesses, coding tools,
  cognitive memory, checkpoint storage, security guardrails, and the
  benchmarking suite. See `DESIGN.md` for the full subsystem breakdown.
- `android_mobi_nooa/` — Android (Kotlin) library module that bridges
  native device capabilities and the `mobi_nooa_core` agent engine via a
  headless Flutter engine + `MethodChannel` (see `MobiNooaBridge.kt` and
  ADR 0007). `MobiNooaService`/`MobiNooaWorker` call into the bridge;
  `DeviceHarnessBridge`/`OnDeviceModelEngine` remain scaffolds — see
  `DESIGN.md`'s open architecture questions.
- `mobi_nooa_bridge/` — thin Flutter "add-to-app" shim (Dart + Flutter)
  with no UI; its only job is forwarding `MethodChannel` calls into
  `mobi_nooa_core`'s `AgentBridgeDispatcher`. Only ever run headless,
  embedded from Android.

## Working conventions

- **Language/style**: Dart code follows `package:lints/recommended` (see
  `mobi_nooa_core/analysis_options.yaml` if present, otherwise default Dart
  style — 2-space indent, `lowerCamelCase` members, `UpperCamelCase` types).
  Kotlin/Gradle code follows standard Android/Kotlin conventions.
- **Public API surface**: All public exports go through
  `mobi_nooa_core/lib/mobi_nooa_core.dart`, grouped by subsystem with a
  comment header (Agent Core, Object Heap, CodeAct, Loop, Models, Harness,
  BenchAgent/Tools, Security, Memory, Storage, Strategies, Bench, Util,
  Tracing). If you add a new public class, export it in the matching group
  (or add a new group comment if it's a genuinely new subsystem).
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
- **New harness capabilities**: implement the relevant `*Harness` interface
  under `lib/src/harness/` and follow the naming pattern `*_harness.dart`
  (see the `.github/skills/add-nooa-harness/SKILL.md` skill for the full
  procedure). Wire new harnesses into `HarnessApi`.
- **New coding tools** (`lib/src/tools/`): build on top of an existing
  harness (typically `FileSystemHarness` or a dedicated `ShellHarness`) —
  don't call `dart:io` directly from a tool if a harness abstraction already
  exists for that capability. Return a typed result object (see
  `FileEditorResult`, `ShellExecutionResult`) with a `toString()` suitable
  for direct LLM consumption.
- **New execution strategies** (`lib/src/strategies/`): implement
  `ExecutionStrategy` (`buildStrategyPrompt` + `processResponse`) rather than
  branching logic inside `AgentLoop`. Return `StrategyStepResult.continueLoop`
  or `.finish` to signal the loop.
- **CodeAct snippets are validated before execution**: any new code path
  that executes an LLM-authored snippet must run it through
  `AstGuardrails.validate` first (see `lib/src/security/ast_guardrails.dart`).
  Don't bypass this for "trusted" snippets — the guardrail is the single
  choke point for denylisted identifiers/patterns.
- **Long-term memory is owner-gated**: use `OwnerGatedMemoryScope`
  (`lib/src/memory/owner_gated_memory.dart`) to read/write a
  `CognitiveMemoryStore` in any multi-agent context; don't call the store
  directly with a raw `ownerId` outside of the scope wrapper.
- **Checkpoints go through `StateStorageManager`**: persist/resume agent
  state via `AgentCheckpoint` + `StateStorageManager`
  (`lib/src/storage/`), not bespoke JSON I/O.
- **New platform-bridge actions**: add them to `AgentBridgeDispatcher`
  (`lib/src/bridge/agent_bridge_dispatcher.dart`) via `registerAgent`/
  `registerModelProvider` or a new `action` case in `handle()` — do not
  hand-roll a separate `MethodChannel` handler in `mobi_nooa_bridge/` or a
  new ad-hoc bridge path in Kotlin. The dispatcher is the single seam
  between `mobi_nooa_core` and any host platform (see ADR 0007).

## Build, test, and validate

Run these from the relevant module directory (not repo root — there is no
root-level build tool yet).

```powershell
# Dart core
cd mobi_nooa_core
dart pub get          # install/update dependencies
dart analyze          # static analysis — must be clean before committing
dart test             # run unit tests

# Flutter bridge shim (headless, no UI)
cd mobi_nooa_bridge
flutter pub get
flutter analyze
flutter test

# Android library
cd android_mobi_nooa
./gradlew build       # compile + lint + unit tests

# Full end-to-end build (Kotlin + headless Flutter bridge + Dart core),
# from the repo root — requires local.properties (copy from
# local.properties.example) with sdk.dir/flutter.sdk set:
./gradlew :app:assembleDebug
```

Always run `dart analyze` and `dart test` (or the equivalent Gradle task)
after modifying Dart or Kotlin source, and paste failing output back into
context rather than guessing at fixes.

## How to Build Applications with mobi-nooa (AI Developer Guide)

When assisting users or generating application code with `mobi-nooa`, follow this architectural workflow:

### 1. Choosing a Built-in Reference Agent
`mobi-nooa` provides 5 pre-built reference agents under `mobi_nooa_core/lib/src/agent/`:
- **`AutonomousDeviceAgent`**: Mobile system triage, battery monitoring, notifications, vibration, and **two-way procedural skills** (`searchSkills`, `loadSkill`, `learnSkill`).
- **`DataAnalystAgent`**: Large dataset manipulation via pass-by-reference handles (`#ref_xxx`) in `ObjectHeap` and on-device SQLite analytics.
- **`AutonomousCodingAgent`**: Software engineering agent with line-numbered file viewing, exact `strReplace`, `createFile`, shell execution, and code searching.
- **`BenchAgent`**: Official NVIDIA port for SWE-bench & CyberGym benchmark evaluations.
- **`GeneralMobileAgent`**: Lightweight baseline assistant for simple mobile tasks.

### 2. Providing an LLM Backend
Agents require a `ModelClient`. AI developers can provision:
- **Quantized On-Device Inference** (`OnDeviceModelClient`): Supports offline execution on mobile hardware via `llama.cpp` (GGUF) or `LiteRT-LM` with prompt formatting templates (`llama3`, `chatMl`, `gemma`, `raw`).
- **Cloud Providers**: `GeminiClient` (Google Gemini 1.5 Pro/Flash), `OpenAIClient` (GPT-4o), `AnthropicClient` (Claude 3.5 Sonnet), `OllamaClient` (local workstation Ollama).

```dart
// 3-Line Quickstart Pattern
final agent = Quickstart.createAgent(
  () => AutonomousDeviceAgent(),
  model: OnDeviceModelClient(template: PromptTemplate.llama3),
);
final result = await agent.ellipsis<String>('Triage battery drain', maxSteps: 5);
```

### 3. Enabling Two-Way Runtime Skills (`nooa-skills`, ADR 0009)
Skills provide deterministic procedural knowledge to ensure consistent outcomes across model switches (cloud to 1B–3B on-device models):
- **Inbound Skills (TO the Agent)**: `SkillPromptEnhancer` searches `SkillStore` (`InMemorySkillStore`, `FileSystemSkillStore`) and injects matching checklists/recipes into the LLM system prompt based on the task goal.
- **Outbound Skills (FROM the Agent)**: Agents synthesize newly discovered workflows via `learnSkill` (or `SkillHarness.createSkill`), persisting them as JSON files in `/skills/`.
- **Approved Skill Repositories & Device Profiles**: Ingest device-specific skill packs (e.g. Pixel Tensor NPU optimization, Samsung OneUI background retention) from user-approved repository paths matching introspected `DeviceHarness` profiles.

### 4. Android Host App Integration Seams
- Native host app integrates `android_mobi_nooa` library.
- Background execution: `MobiNooaService` (non-killable Foreground Service) or `MobiNooaWorker` (WorkManager periodic scheduler).
- Transport seam: `MobiNooaBridge.kt` calls `com.mobi.nooa/agent_bridge` -> `mobi_nooa_bridge/lib/main.dart` -> `AgentBridgeDispatcher.handle()`.
- Native hardware queries: `com.mobi.nooa/device_harness` calls into `DeviceHarnessBridge.kt`.

## Guardrails

- Do not add a dependency on `flutter`/`dart:ui` to `mobi_nooa_core` — it must
  stay platform-agnostic and usable from plain Dart or server-side contexts.
- Do not commit secrets, API keys, or `local.properties`. Model provider API
  keys are supplied by the host app at runtime via `ModelClient` constructors.
- Do not bypass `AgentContext`/`ObjectHeap`/`Tracer` when adding new agent
  capabilities — every state mutation, tool call, and error should be
  observable through the existing tracing (`TraceEventType`) so agent runs
  stay debuggable.
- Do not let CodeAct snippets reach `SandboxedEnvironment`/`CodeActEngine`
  without first passing `AstGuardrails.validate` — this is a security
  choke point, not an optional check.
- Do not read/write `CognitiveMemoryStore` with a raw owner ID outside an
  `OwnerGatedMemoryScope` — that is how per-agent memory isolation is
  enforced.
- Ingested external skills must pass through `AstGuardrails` and only originate
  from user-approved skill repositories configured in the harness.
- When a change affects architecture or a NOOA principle's implementation,
  add or update an ADR in `docs/decisions/` and update `DESIGN.md`.
- Prefer small, verifiable, single-purpose commits. If a task is ambiguous
  (e.g. which model provider to prioritize, which harness to build next),
  ask before proceeding rather than guessing.

## Skills for Repository Development

Repeatable, checklist-driven developer skills live in `.github/skills/`:

- `.github/skills/add-nooa-agent/SKILL.md` — how to create a new
  object-oriented agent (`NooaAgent` subclass) implementing NOOA principles.
- `.github/skills/add-nooa-harness/SKILL.md` — how to add a new
  model-callable harness capability (NOOA Principle 6).
- `.github/skills/add-nooa-strategy/SKILL.md` — how to add a new
  execution reasoning strategy (NOOA Principle 4).
- `.github/skills/technical-writer/SKILL.md` — how to author, structure,
  and verify user and developer documentation across the project.

## Where to look for examples

- Reference agent implementations: `mobi_nooa_core/lib/src/agent/`
  (`autonomous_device_agent.dart`, `data_analyst_agent.dart`,
  `autonomous_coding_agent.dart`, `bench_agent.dart`, `general_mobile_agent.dart`)
- Application Integration Guide: `docs/reference_agents.md`, `docs/developer_guide.md`, `docs/android_integration.md`
- Skills subsystem: `mobi_nooa_core/lib/src/skills/`
- On-device model client: `mobi_nooa_core/lib/src/models/on_device_client.dart`
- Agentic loop / step execution: `mobi_nooa_core/lib/src/loop/agent_loop.dart`
- Bridge dispatcher: `mobi_nooa_core/lib/src/bridge/agent_bridge_dispatcher.dart`
- Adding a tool/action: `registerAction(...)` calls in a `NooaAgent` subclass
- Adding a model provider: `mobi_nooa_core/lib/src/models/*_client.dart`
- Adding a harness: `mobi_nooa_core/lib/src/harness/*_harness.dart`
- Cognitive memory usage: `mobi_nooa_core/lib/src/memory/`
- Checkpoint persistence: `mobi_nooa_core/lib/src/storage/`
- CodeAct security checks: `mobi_nooa_core/lib/src/security/ast_guardrails.dart`
- Benchmark suites: `mobi_nooa_core/lib/src/bench/`,
  `mobi_nooa_core/example/run_benchmarks.dart`
