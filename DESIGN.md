# DESIGN.md — mobi-nooa Architecture

## Purpose

mobi-nooa adapts NVIDIA's NOOA framework (*labs-OO-Agents*, arXiv:2607.20709)
— originally a Python object-oriented agent framework — into Dart (core
logic) and Kotlin (Android integration), so agentic AI loops can run
on-device on mobile hardware, with or without a persistent server connection.

## The six NOOA principles, and where they live in this repo

| # | Principle | Implementation |
|---|---|---|
| 1 | **Class-as-agent**: the class defines the agent; docstrings/type annotations double as LLM prompts and tool contracts. | `lib/src/agent/nooa_agent.dart`, `annotations.dart` |
| 2 | **Pass-by-reference object heap**: large/complex objects are stored once and referenced by handle in prompts, not inlined. | `lib/src/heap/object_heap.dart`, `object_reference.dart`, `bounded_preview.dart` |
| 3 | **Code as Action (CodeAct)**: the agent can emit executable code snippets as actions, run in a sandboxed evaluator. | `lib/src/engine/sandboxed_environment.dart`, `ast_evaluator.dart`, `code_act_engine.dart` |
| 4 | **Programmable loop engineering**: the step loop (prompt → model call → tool/code execution → repeat) is an explicit, configurable component, not hidden framework magic. | `lib/src/loop/agent_loop.dart`, `loop_config.dart`, `step_event.dart` |
| 5 | **Explicit state**: agent state is a first-class, inspectable/serializable map, not scattered instance fields. | `NooaAgent._state`, `setState`/`getState`/`getStateSnapshot`/`restoreState` |
| 6 | **Model-callable harness APIs**: device/system capabilities (filesystem, network, memory, device, MCP) are exposed as harnesses the agent can invoke as tools. | `lib/src/harness/*_harness.dart`, `harness_api.dart` |

Additional cross-cutting concerns:

- **Model abstraction**: `lib/src/models/model_client.dart` defines the
  provider-agnostic interface; concrete clients exist for OpenAI, Anthropic,
  Gemini, Ollama, on-device models, and a deterministic `mock_client.dart`
  for tests.
- **Tracing/telemetry**: `lib/src/tracing/tracer.dart` +
  `trace_event.dart` record every step, tool call, code execution, error,
  and subagent spawn — this is the debugging/observability backbone.
- **Subagent orchestration**: `NooaAgent.spawnSubagent` creates a child
  `AgentContext` and delegates a subtask, enabling multi-agent decomposition.

## Module boundaries

```
mobi_nooa_core/            (Dart, platform-agnostic)
  lib/src/agent/           agent base class, context, reflection/prompt building
  lib/src/heap/            object heap + pass-by-reference handles
  lib/src/engine/          sandboxed code execution (CodeAct)
  lib/src/loop/            the agentic step loop + config
  lib/src/models/          LLM provider clients
  lib/src/harness/         model-callable capability APIs
  lib/src/tracing/         structured tracing/telemetry

android_mobi_nooa/         (Kotlin, Android library)
  build.gradle.kts         Android library module (namespace com.mobi.nooa,
                           minSdk 26, targetSdk/compileSdk 34)
```

`android_mobi_nooa` depends on `mobi_nooa_core` conceptually (via platform
channel/FFI bridge, not yet implemented) to expose real device harnesses
(sensors, storage, connectivity) instead of the pure-Dart stand-ins.

## Design invariants (do not violate without an ADR)

1. `mobi_nooa_core` has zero Flutter/UI dependencies — it must run in plain
   Dart, server-side, or embedded in Android via Dart-native interop.
2. All LLM-visible state passes through the object heap or explicit agent
   state — never ad-hoc closures capturing large objects.
3. Every meaningful runtime event (step start/end, tool call, code
   execution, error, subagent spawn) is recorded via `Tracer`.
4. Model providers are interchangeable behind `ModelClient`; no
   agent/loop/harness code should import a specific provider SDK directly.

## Open architecture questions

Track these as ADRs in `docs/decisions/` once decided:

- Bridge mechanism between `android_mobi_nooa` (Kotlin) and
  `mobi_nooa_core` (Dart): platform channels vs. `dart:ffi` vs. a separate
  Flutter app shell.
- Persistence strategy for agent state/heap across process restarts.
- Sandboxing strategy hardening for `CodeActEngine` on-device (security
  boundary for arbitrary generated code).
