# AGENTS.md

Instructions for AI coding agents (GitHub Copilot, Claude, Copilot CLI, Antigravity, etc.)
working in the **mobi-nooa** repository. Read this before making changes.

## What this project is

**mobi-nooa** is a high-performance mobile agentic runtime and harness designed to turn modern Android devices into autonomous, object-oriented AI agent engines. It faithfully implements the architecture and principles of **NVIDIA's Object-Oriented Agents (NOOA)** ([`NVIDIA-NeMo/labs-OO-Agents`](https://github.com/NVIDIA-NeMo/labs-OO-Agents), arXiv:[2607.20709](https://arxiv.org/abs/2607.20709)) fused with the plugin-first, tiered permission, and append-only event logging architecture of **DeepSeek Harness** ([`deepseek-ai/deepseek-harness`](https://github.com/deepseek-ai/deepseek-harness)).

### Primary Repository Modules

- `mobi_nooa_core/` — pure Dart library, no Flutter/UI dependency. This is
  where core agent logic lives: agent core, object heap, CodeAct engine,
  programmable loop, pluggable execution strategies, model clients, harnesses,
  coding tools, cognitive memory, checkpoint storage, plugin registry, tiered
  permission manager, append-only session event logs, adaptive resource governor,
  AST security guardrails, and benchmarking suite. See `DESIGN.md` for details.
- `android_mobi_nooa/` — Android (Kotlin) library module that bridges
  native device capabilities and the `mobi_nooa_core` agent engine via a
  headless Flutter engine + `MethodChannel` (see `MobiNooaBridge.kt` and
  ADR 0007). `MobiNooaService` (non-killable Foreground Service) and
  `MobiNooaWorker` (WorkManager scheduler) call into the bridge.
- `mobi_nooa_bridge/` — thin Flutter "add-to-app" shim (Dart + Flutter)
  with no UI; its only job is forwarding `MethodChannel` calls into
  `mobi_nooa_core`'s `AgentBridgeDispatcher`. Only ever run headless,
  embedded from Android.
- `app/` — minimal Android host application required for the Flutter Gradle
  plugin's add-to-app pattern and full APK assembly.

---

## Working conventions

- **Language/style**: Dart code follows `package:lints/recommended` (2-space indent, `lowerCamelCase` members, `UpperCamelCase` types). Kotlin/Gradle code follows standard Android/Kotlin conventions.
- **Public API surface**: All public exports go through `mobi_nooa_core/lib/mobi_nooa_core.dart`, grouped by subsystem with a comment header (Agent Core, Object Heap, CodeAct, Loop, Models, Harness, BenchAgent/Tools, Security, Plugins, Session, Memory, Storage, Strategies, Bench, Util, Tracing, Governor).
- **Docstrings double as prompts**: Per NOOA Principle 1, `NooaAgent` methods' doc comments and type annotations are used to build LLM tool-call prompts. Keep doc comments accurate and concise — they are runtime-visible contracts.
- **State goes through `setState`/`getState`**: Agents must not use ad-hoc instance fields for state the LLM needs to reason about; use the explicit `_state` map via `NooaAgent.setState`/`getState` (NOOA Principle 5).
- **Large objects go through the heap**: Don't return large blobs directly from tool calls — wrap them with `ObjectHeap.maybeWrap` so the LLM gets a pass-by-reference handle (`#ref_xxx`) instead of a huge payload (NOOA Principle 2).
- **Plugins follow Service Seam pattern**: Dynamic tools, middleware, and interceptors implement `AgentPlugin` (`lib/src/plugin/`) and register on `PluginRegistry` rather than polluting agent classes.
- **Mobile permissions are decoupled**: Sensitive actions (file writes, shell execution, telephony, notifications) must be evaluated via `PermissionManager` against `PermissionPolicy` and support interactive `ApprovalCallback`s.
- **New model providers**: implement `ModelClient` (see `lib/src/models/model_client.dart`) and mirror the structure of an existing client (e.g. `deepseek_client.dart`, `openai_client.dart`).
- **New harness capabilities**: implement the relevant `*Harness` interface under `lib/src/harness/` and follow the naming pattern `*_harness.dart` (see `.github/skills/add-nooa-harness/SKILL.md`). Wire new harnesses into `HarnessApi`.
- **New coding tools** (`lib/src/tools/`): build on top of an existing harness (typically `FileSystemHarness` or `ShellHarness`) — don't call `dart:io` directly from a tool. Return typed result objects with a `toString()` suitable for LLM consumption.
- **New execution strategies** (`lib/src/strategies/`): implement `ExecutionStrategy` (`buildStrategyPrompt` + `processResponse`) rather than branching logic inside `AgentLoop`.
- **CodeAct snippets are validated before execution**: any new code path executing an LLM-authored snippet must run it through `AstGuardrails.validate` first (`lib/src/security/ast_guardrails.dart`).
- **Long-term memory is owner-gated**: use `OwnerGatedMemoryScope` (`lib/src/memory/owner_gated_memory.dart`) to read/write a `CognitiveMemoryStore` in any multi-agent context.
- **Checkpoints go through `StateStorageManager`**: persist/resume agent state via `AgentCheckpoint` + `StateStorageManager` (`lib/src/storage/`).
- **Platform-bridge actions**: add them to `AgentBridgeDispatcher` (`lib/src/bridge/agent_bridge_dispatcher.dart`) via `registerAgent`/`registerModelProvider` or a new `action` case in `handle()`.

---

## Build, test, and validate

Run commands from the relevant module directory:

```powershell
# 1. Dart Core
cd mobi_nooa_core
dart pub get          # install/update dependencies
dart analyze          # static analysis — must be 100% clean
dart test --exclude-tags live  # run full unit & integration test suite

# 2. Flutter Bridge Shim (headless, no UI)
cd ../mobi_nooa_bridge
flutter pub get
flutter analyze
flutter test

# 3. Android Native Library
cd ../android_mobi_nooa
./gradlew build       # compile + lint + unit tests

# 4. Full End-to-End Android APK Build (Kotlin + Flutter bridge + Dart core)
# Run from repo root (requires local.properties configured):
./gradlew :app:assembleDebug
```

---

## How to Build Applications with mobi-nooa (AI Developer Guide)

### 1. Choosing a Built-in Reference Agent
`mobi-nooa` provides 5 pre-built reference agents under `mobi_nooa_core/lib/src/agent/`:
- **`AutonomousDeviceAgent`**: Mobile system triage, battery monitoring, notifications, vibration, and **two-way procedural skills** (`searchSkills`, `loadSkill`, `learnSkill`).
- **`DataAnalystAgent`**: Large dataset manipulation via pass-by-reference handles (`#ref_xxx`) in `ObjectHeap` and on-device SQLite analytics.
- **`AutonomousCodingAgent`**: Software engineering agent with line-numbered file viewing, exact `strReplace`, `createFile`, shell execution, and symbol searching.
- **`BenchAgent`**: Official NVIDIA port for SWE-bench & CyberGym benchmark evaluations.
- **`GeneralMobileAgent`**: Lightweight baseline assistant for simple mobile tasks.

### 2. Providing an LLM Backend
Agents require a `ModelClient`. AI developers can provision:
- **DeepSeek AI** (`DeepSeekClient`): DeepSeek-R1 (`deepseek-reasoner`) with reasoning token extraction (`reasoning_content` / `<think>`) and DeepSeek-V3 (`deepseek-chat`) with prompt cache telemetry.
- **Quantized On-Device Inference** (`OnDeviceModelClient`): Offline execution on mobile hardware via `llama.cpp` (GGUF) or `LiteRT-LM` with prompt formatting templates (`llama3`, `chatMl`, `gemma`, `raw`).
- **Cloud Providers**: `GeminiClient` (Google Gemini 1.5 Pro/Flash), `OpenAIClient` (GPT-4o), `AnthropicClient` (Claude 3.5 Sonnet), `OllamaClient` (local Ollama), `NvidiaClient` (NVIDIA NIM).

```dart
// 3-Line Quickstart Pattern with DeepSeek-R1
final agent = Quickstart.createAgent(
  () => AutonomousDeviceAgent(),
  model: DeepSeekClient(apiKey: 'sk-deepseek-...', modelName: 'deepseek-reasoner'),
);
final result = await agent.ellipsis<String>('Triage battery drain', maxSteps: 5);
```

### 3. Enabling Two-Way Runtime Skills (`nooa-skills`, ADR 0009)
Skills provide deterministic procedural knowledge to ensure consistent outcomes across model switches (cloud to 1B–3B on-device models):
- **Inbound Skills**: `SkillPromptEnhancer` searches `SkillStore` (`InMemorySkillStore`, `FileSystemSkillStore`) and injects matching checklists/recipes into the LLM system prompt.
- **Outbound Skills**: Agents synthesize newly discovered workflows via `learnSkill` (or `SkillHarness.createSkill`), persisting them as JSON files in `/skills/`.

### 4. Leveraging the Plugin Architecture (`nooa-plugins`, ADR 0011)
Extend agents dynamically via `AgentPlugin` and `PluginRegistry`:
```dart
final plugins = PluginRegistry()
  ..register(TelemetryLoggerPlugin(onLog: (record) => print('Event: $record')))
  ..register(DynamicToolPlugin()..registerAction(
    name: 'calculateTax',
    description: 'Calculates tax amount',
    invoker: (args) async => (args['amount'] as num) * 0.2,
  ));

final agent = Quickstart.createAgent(
  () => GeneralMobileAgent(),
  model: mockModel,
  plugins: plugins,
);
```

### 5. Enforcing Decoupled Permissions (`nooa-security`, ADR 0011)
Attach `PermissionManager` with interactive callbacks to prompt users before dangerous operations:
```dart
final permissions = PermissionManager(
  policy: PermissionPolicy.defaultMobile(),
  approvalHandler: (request) async {
    // Show Android Dialog / Notification Prompt
    return await showUserConfirmationDialog(request.actionName, request.arguments);
  },
);
```

### 6. Managing Sessions with Time-Travel & Branch Forking (`nooa-session`, ADR 0011)
```dart
final sessionLog = SessionEventLog(sessionId: 'session_01');
final agent = Quickstart.createAgent(
  () => AutonomousCodingAgent(),
  sessionLog: sessionLog,
);

await agent.ellipsis<String>('Refactor authentication module');

// Replay state at step 2
final historicalState = sessionLog.replay(2);

// Fork into an experimental branch from step 2
final forkedLog = sessionLog.fork(newSessionId: 'session_01_experiment', fromStepIndex: 2);
```

### 7. Adaptive Resource Governor (`nooa-governor`, ADR 0010)
Use `DeviceResourceGovernor` to protect device stability:
- Detects RAM pressure, thermal throttling, and battery status.
- Automatically reduces agent concurrency and switches heavy on-device NPU tasks to cloud offload or eco-delays.

### 8. Comprehensive Testing Methodology & TDD for Agentic AI
`mobi-nooa` enforces a **4-Tier Testing Pyramid** aligned with NOOA design invariants and mobile constraints:

```
           / \
          / 4 \     Tier 4: Live On-Device Instrumentation & UI Tests (ADB / Hardware)
         /-----\
        /   3   \   Tier 3: Android Native Kotlin JVM Unit Tests (Domain / UDF ViewModels)
       /---------\
      /     2     \ Tier 2: Headless Flutter Bridge MethodChannel Tests (Platform Boundary)
     /-------------\
    /       1       \ Tier 1: Pure In-Memory Dart Core Unit Tests (19 Subsystems, Mock Clients)
   /-----------------\
```

#### Tier 1: Pure In-Memory Core Tests (`mobi_nooa_core/test/`)
- **Fast & Deterministic**: Zero network calls, zero device dependencies. Executes 110+ tests in under 2 seconds.
- **Coverage**:
  - **12 Fallback Cascade Permutations** (`test/models/fallback_cascade_client_test.dart`): Nominal primary success, in-tier retries, 503 HTTP failovers, timeouts, 4-tier N-way chains, all-exhausted exceptions, mid-trajectory tool execution failovers, schema preservation, DeepSeek-R1 reasoning content extraction, bridge JSON configuration, single-provider pass-through, and `reset()`.
  - **Reference Agents & Heap** (`test/reference_agents_test.dart`, `test/nooa_principles_test.dart`): All 5 reference agents, `#ref_xxx` handle allocations, LRU cache compaction, and state isolation.
  - **AST Security Guardrails** (`test/security_injection_test.dart`, `test/permission_manager_test.dart`): CodeAct sandboxing, shell command injection defenses, path traversal protection, and interactive permission callbacks.
  - **Coding Tools & Harnesses** (`test/tools_and_harnesses_test.dart`): `FileEditorTool`, `CodeSearchTool`, `InMemorySqliteHarness`, `MemoryFileSystemHarness`, and `DefaultDeviceHarness`.
  - **Time-Travel & Branch Forking** (`test/session_event_log_test.dart`): Event replay and immutable branch forking.
  - **Resource Governor** (`test/resource_governor_test.dart`): Thermal pressure, RAM budgets, and load balancing.

#### Tier 2: Headless Flutter Bridge Tests (`mobi_nooa_bridge/test/`)
- Verifies MethodChannel request decoding, dispatcher action routing (`runAgentLoop`, `replaySession`, `forkSession`, `getDeviceTelemetry`, `assessBudget`, `compactHeap`), and JSON response formatting.

#### Tier 3: Android Native Kotlin Tests (`android_mobi_nooa/src/test/`)
- Tests Clean Architecture use cases, UDF MVI ViewModels (`AgentHubViewModel`, `AgentExecutionViewModel`, `SessionTimelineViewModel`, `ResourceGovernorViewModel`), and repository mapping on the JVM via `FakeAgentRepository`.

#### Tier 4: Live On-Device Integration Tests (`scratch/test_device_cascade_permutations.ps1`)
- Runs against live Android emulator (`emulator-5554`) or physical device:
  - Automates UI tab switching and button presses via ADB.
  - Triggers live model inference with fallback cascades to local on-device quantized models.
  - Asserts real-time UI state, console logs (`✓ EXECUTION COMPLETE`), and trace rendering.

#### Strict TDD (Red -> Green -> Refactor) Workflow:
1. **RED (Write Failing Test First)**:
   - Use `MockConfigurableModelClient` or `MockFailingModelClient` to simulate multi-step tool calls, thoughts, and failure modes deterministically.
   - Assert expected tool arguments, state mutations (`getState`), and return payloads before writing implementation code.
2. **GREEN (Implement Minimum Behavior)**:
   - Write the agent actions, harness methods, or plugin logic until `dart test` or `./gradlew test` passes.
3. **REFACTOR & SECURE**:
   - Verify security guardrails (`AstGuardrails.validate`, `PermissionManager.authorize`), wrap large blobs into `ObjectHeap.maybeWrap`, and ensure static analysis (`dart analyze` / `flutter analyze`) is 100% clean.

---

## Guardrails & Invariants

- Do not add a dependency on `flutter`/`dart:ui` to `mobi_nooa_core` — it must stay platform-agnostic and usable from plain Dart or server-side contexts.
- Do not commit secrets, API keys, or `local.properties`. Model provider API keys are supplied by the host app at runtime via `ModelClient` constructors.
- Do not bypass `AgentContext`/`ObjectHeap`/`Tracer` when adding new capabilities — every state mutation, tool call, and error should be observable.
- Do not let CodeAct snippets reach `SandboxedEnvironment`/`CodeActEngine` without first passing `AstGuardrails.validate`.
- Do not read/write `CognitiveMemoryStore` with a raw owner ID outside an `OwnerGatedMemoryScope`.
- Prefer small, verifiable, single-purpose commits.

---

## Skills for Repository Development

Repeatable, checklist-driven developer skills live in `.github/skills/`:

- `.github/skills/add-nooa-agent/SKILL.md` — how to create a new object-oriented agent (`NooaAgent` subclass).
- `.github/skills/add-nooa-plugin/SKILL.md` — how to build modular plugins, service seams, middleware hooks, and dynamic tools.
- `.github/skills/add-nooa-harness/SKILL.md` — how to add a new model-callable harness capability (NOOA Principle 6).
- `.github/skills/add-nooa-strategy/SKILL.md` — how to add a new execution reasoning strategy (NOOA Principle 4).
- `.github/skills/deploy-mobi-nooa/SKILL.md` — how to deploy `mobi-nooa` on Android, headless Flutter, on-device GGUF, or CLI.
- `.github/skills/design-mobi-nooa-ui/SKILL.md` — how to design, generate, and maintain mobile UI/UX screens using Stitch MCP following the Neo-Neural Agentic Interface.
- `.github/skills/test-mobi-nooa/SKILL.md` — how to design, write, and execute tests across the 4-tier testing pyramid and enforce strict TDD for agentic AI.
- `.github/skills/technical-writer/SKILL.md` — how to author, structure, and verify user and developer documentation across the project.

