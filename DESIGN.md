# DESIGN.md — mobi-nooa Architecture

## Purpose

mobi-nooa adapts NVIDIA's NOOA framework (*labs-OO-Agents*, arXiv:2607.20709)
— originally a Python object-oriented agent framework — into Dart (core
logic) and Kotlin (Android integration), so agentic AI loops can run
on-device on mobile hardware, with or without a persistent server connection.
On top of the six core NOOA principles, this repo also implements a
`BenchAgent` (an autonomous software-engineering agent following the
NOOA paper's reference `BenchAgent` design), a cognitive long-term memory
subsystem, pluggable execution strategies, SQLite-backed persistence, and
an AST-level security layer for CodeAct — see below for where each lives.

## The six NOOA principles, and where they live in this repo

| # | Principle | Implementation |
|---|---|---|
| 1 | **Class-as-agent**: the class defines the agent; docstrings/type annotations double as LLM prompts and tool contracts. | `lib/src/agent/nooa_agent.dart`, `annotations.dart` |
| 2 | **Pass-by-reference object heap**: large/complex objects are stored once and referenced by handle in prompts, not inlined. | `lib/src/heap/object_heap.dart`, `object_reference.dart`, `bounded_preview.dart` |
| 3 | **Code as Action (CodeAct)**: the agent can emit executable code snippets as actions, run in a sandboxed evaluator. | `lib/src/engine/sandboxed_environment.dart`, `ast_evaluator.dart`, `code_act_engine.dart` |
| 4 | **Programmable loop engineering**: the step loop (prompt → model call → tool/code execution → repeat) is an explicit, configurable component, not hidden framework magic. | `lib/src/loop/agent_loop.dart`, `loop_config.dart`, `step_event.dart` |
| 5 | **Explicit state**: agent state is a first-class, inspectable/serializable map, not scattered instance fields. | `NooaAgent._state`, `setState`/`getState`/`getStateSnapshot`/`restoreState` |
| 6 | **Model-callable harness APIs**: device/system capabilities (filesystem, network, memory, device, SQLite, MCP) are exposed as harnesses the agent can invoke as tools. | `lib/src/harness/*_harness.dart`, `harness_api.dart` |

## Reference agent implementations

| Agent | Purpose | Key file |
|---|---|---|
| `GeneralMobileAgent` | Minimal example agent: device telemetry + note-taking. Used by the CLI (`bin/mobi_nooa.dart`) as the default demo agent. | `lib/src/agent/general_mobile_agent.dart` |
| `BenchAgent` | Autonomous software-engineering agent (NOOA paper reference architecture) combining shell execution, file viewing/editing (`strReplace`, `createFile`), and codebase search/symbol listing. Designed to be benchmark-agnostic (SWE-bench, Terminal-Bench, CyberGym). | `lib/src/agent/bench_agent.dart` |

Example/demo agents (not part of the public library API, illustrate usage
patterns): `mobi_nooa_core/example/data_scientist_agent.dart`,
`mobile_assistant_agent.dart`, `run_benchmarks.dart`.

## Subsystems beyond the six principles

### Coding tools (`lib/src/tools/`)

Reusable, harness-backed tool implementations consumed by `BenchAgent` (and
any future coding agent):

- `shell_tool.dart` — `ShellHarness` abstraction + `LocalShellHarness`,
  which shells out to `powershell`/`bash`, tracks a virtual working
  directory (handles `cd`), enforces output truncation, and applies a
  timeout with hard process kill.
- `file_editor_tool.dart` — `FileEditorTool` provides `viewFile` (line-
  numbered, paginated), `strReplace` (unique-match-required replace, mirrors
  SWE-bench's edit tool), and `createFile`, all built on `FileSystemHarness`.
- `code_search_tool.dart` — `CodeSearchTool` provides `findFiles`, regex
  `grep` across the sandboxed filesystem, and lightweight `extractSymbols`
  (regex-based class/function outline extraction, language-agnostic).

### Execution strategies (`lib/src/strategies/`)

`ExecutionStrategy` is an abstract contract (`buildStrategyPrompt`,
`processResponse`) that lets an agent's reasoning pattern be swapped
independently of `AgentLoop`'s mechanics. Implementations:

- `react_strategy.dart` — `ReActStrategy`: explicit Thought → Action →
  Observation cycling, terminating on a `Final Answer:` marker.
- `code_act_strategy.dart` — CodeAct-oriented strategy variant.
- `plan_and_solve_strategy.dart` — upfront plan generation followed by
  step-wise execution.
- `self_reflection_strategy.dart` — adds a self-critique/revision pass.

`StrategyStepResult` (in `execution_strategy.dart`) is the strategy → loop
contract: `continueLoop(...)` or `finish(...)`.

### Cognitive memory (`lib/src/memory/`)

Implements the `nooa-memory` long-term memory subsystem, distinct from the
short-term `MemoryHarness` KV/vector store in `lib/src/harness/`:

- `act_r_memory.dart` — `CognitiveMemoryRecord` (content + tags + importance
  + access history + embedding) and `ActRActivationCalculator`, which scores
  memories using an ACT-R-style base-level activation with Ebbinghaus
  power-law decay (`B_i = ln(Σ (t - t_k)^-d)`) plus an importance bonus and
  contextual (embedding cosine-similarity) bonus. `CognitiveMemoryStore`
  ranks and recalls memories by this activation score, reinforcing on access.
- `owner_gated_memory.dart` — `OwnerGatedMemoryScope` wraps a
  `CognitiveMemoryStore` and strictly scopes `remember`/`recall` to one
  `ownerId`, enforcing per-agent memory isolation in multi-agent setups.

### Storage & checkpointing (`lib/src/storage/`)

Implements the `nooa.storage` persistence architecture for pause/resume and
crash recovery:

- `agent_checkpoint.dart` — `AgentCheckpoint`: a JSON-serializable snapshot
  of an agent's state map, step index, heap references, and status
  (`running`/`paused`/`completed`/`error`), with `toJsonString`/
  `fromJsonString`.
- `state_storage_manager.dart` — `StateStorageManager` persists/retrieves
  `AgentCheckpoint`s via a `SqliteHarness` (`lib/src/harness/sqlite_harness.dart`),
  creating an `agent_checkpoints` table and exposing `saveCheckpoint`,
  `getLatestCheckpoint`, `listCheckpoints`.

### Security guardrails (`lib/src/security/`)

`ast_guardrails.dart` — `AstGuardrails` is a defense-in-depth static
validator run against CodeAct snippets *before* execution: rejects code over
a length limit, containing denied identifiers (`exit`, `Process.kill`,
`dart:mirrors`, `dart:isolate.spawnUri`, `System.exit`,
`Runtime.getRuntime`), or matching denied regex patterns (e.g. `rm -rf /`,
disk format commands, shell fork bombs). Returns an `AstValidationResult`
with a list of violations. This complements, but does not replace, the
runtime sandboxing in `lib/src/engine/sandboxed_environment.dart`.

### Benchmarking & evaluation (`lib/src/bench/`)

Implements the `nooa.bench` evaluation harness for measuring agent quality
against task suites (SWE-bench-style and mobile-specific):

- `benchmark_suite.dart` — `BenchmarkTask` (prompt + initial workspace files
  + optional verification command/expected substring), `BenchmarkSuite.evaluate`
  runs an agent factory against every task and produces a `BenchmarkReport`
  (pass rate, average steps, total tokens, per-task `BenchmarkTaskResult`,
  JSONL export).
- `swe_bench_runner.dart` — loads/runs SWE-bench-style tasks against
  `BenchAgent`.
- `mobile_bench_runner.dart` — loads/runs mobile-specific task suites.

`mobi_nooa_core/example/run_benchmarks.dart` demonstrates wiring a suite up
end-to-end.

### Utilities (`lib/src/util/`)

- `quickstart.dart` — `Quickstart.createAgent<T>(...)` constructs an agent
  and wires a default `AgentContext` (heap, `HarnessApi`, `MockModelClient`,
  `Tracer`) in one call, for demos/tests that don't need custom wiring.
- `prompt_builder.dart` — `PromptBuilder`: small fluent builder
  (`header`/`item`/`codeBlock`/`text`/`build`) for constructing Markdown-
  formatted prompt sections, plus a static `interpolate` helper for
  `{{variable}}` template substitution.

### Cross-cutting concerns

- **Model abstraction**: `lib/src/models/model_client.dart` defines the
  provider-agnostic interface; concrete clients exist for OpenAI, Anthropic,
  Gemini, Ollama, on-device models, and a deterministic `mock_client.dart`
  for tests.
- **Tracing/telemetry**: `lib/src/tracing/tracer.dart` +
  `trace_event.dart` record every step, tool call, code execution, error,
  and subagent spawn — this is the debugging/observability backbone, and
  what `BenchmarkSuite` reads to compute steps-used/token totals.
- **Subagent orchestration**: `NooaAgent.spawnSubagent` creates a child
  `AgentContext` and delegates a subtask, enabling multi-agent decomposition.

## Module boundaries

```
mobi_nooa_core/            (Dart, platform-agnostic)
  bin/                     CLI entry point (mobi_nooa.dart)
  example/                 Demo agents and benchmark wiring (not exported)
  lib/mobi_nooa_core.dart  Public export surface — every public class must
                           be exported here, grouped by subsystem
  lib/src/agent/           agent base class, context, reflection/prompt
                           building, reference agents (GeneralMobileAgent,
                           BenchAgent)
  lib/src/heap/            object heap + pass-by-reference handles
  lib/src/engine/          sandboxed code execution (CodeAct)
  lib/src/loop/            the agentic step loop + config
  lib/src/strategies/      pluggable reasoning strategies (ReAct, CodeAct,
                           Plan-and-Solve, Self-Reflection)
  lib/src/models/          LLM provider clients
  lib/src/harness/         model-callable capability APIs (fs, network,
                           device, KV/vector memory, SQLite, MCP)
  lib/src/tools/           reusable coding tools (shell, file editor, code
                           search) built on top of harnesses
  lib/src/memory/          long-term cognitive memory (ACT-R activation,
                           owner-gated scoping)
  lib/src/storage/         checkpoint persistence (SQLite-backed)
  lib/src/security/        AST-level guardrails for CodeAct execution
  lib/src/bench/           benchmark task/suite/report model + runners
  lib/src/util/            Quickstart agent wiring, prompt-building helpers
  lib/src/tracing/         structured tracing/telemetry
  test/                    unit tests, one file per subsystem area

android_mobi_nooa/         (Kotlin, Android library)
  build.gradle.kts         Android library module (namespace com.mobi.nooa,
                           minSdk 26, targetSdk/compileSdk 34)
  src/main/kotlin/com/mobi/nooa/
    DeviceHarnessBridge.kt   Native battery/network/notification/vibration
                             access (backs a future Android DeviceHarness)
    MobiNooaService.kt       Foreground Service keeping an agent loop alive
                             past Android background/battery-optimization
                             limits
    MobiNooaWorker.kt        WorkManager CoroutineWorker for scheduled/
                             periodic background agent tasks
    OnDeviceModelEngine.kt   On-device local LLM inference wrapper (intended
                             backend: MediaPipe GenAI / LiteRT / llama.cpp)
```

`android_mobi_nooa` depends on `mobi_nooa_core` conceptually (via platform
channel/FFI bridge, not yet implemented) to expose real device harnesses
(sensors, storage, connectivity) instead of the pure-Dart stand-ins. The
Kotlin classes above are currently scaffolds: `runAgentLoop` in
`MobiNooaService` and `doWork` in `MobiNooaWorker` have the interop points
marked but not wired to the Dart engine yet.

## Design invariants (do not violate without an ADR)

1. `mobi_nooa_core` has zero Flutter/UI dependencies — it must run in plain
   Dart, server-side, or embedded in Android via Dart-native interop.
2. All LLM-visible state passes through the object heap or explicit agent
   state — never ad-hoc closures capturing large objects.
3. Every meaningful runtime event (step start/end, tool call, code
   execution, error, subagent spawn) is recorded via `Tracer`.
4. Model providers are interchangeable behind `ModelClient`; no
   agent/loop/harness code should import a specific provider SDK directly.
5. Every CodeAct snippet passes through `AstGuardrails.validate` before
   reaching `SandboxedEnvironment`/`CodeActEngine` — guardrails are a
   pre-execution gate, not a replacement for sandboxing.
6. Long-term memory (`lib/src/memory/`) is always accessed through an
   owner-scoped view (`OwnerGatedMemoryScope`) in multi-agent contexts —
   agents must not read/write another agent's `ownerId` partition directly
   via the shared `CognitiveMemoryStore`.
7. Checkpoint/state persistence goes through `StateStorageManager` +
   `AgentCheckpoint`, not ad-hoc serialization, so pause/resume and crash
   recovery stay consistent across agents.

## Open architecture questions

Track these as ADRs in `docs/decisions/` once decided:

- Bridge mechanism between `android_mobi_nooa` (Kotlin) and
  `mobi_nooa_core` (Dart): platform channels vs. `dart:ffi` vs. a separate
  Flutter app shell. (`MobiNooaService.runAgentLoop` and
  `MobiNooaWorker.doWork` are the two call sites waiting on this decision.)
- Real on-device model backend selection for `OnDeviceModelEngine.kt`
  (MediaPipe GenAI vs. LiteRT vs. llama.cpp/GGUF) and how it maps to the
  Dart `on_device_client.dart` `ModelClient`.
- Whether `InMemorySqliteHarness` is replaced by a real SQLite binding
  (e.g. `sqlite3` FFI package) for production persistence, or whether that
  swap happens only in the Android bridge layer.
