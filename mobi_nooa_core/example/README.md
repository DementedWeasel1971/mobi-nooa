# mobi-nooa: Progressive Tutorial & Examples

This directory contains a complete, progressive curriculum of runnable examples demonstrating every feature of the **mobi-nooa** mobile agent framework (mirroring the reference tutorials from NVIDIA's `labs-OO-Agents`).

---

## Tutorial Catalog

| # | Example File | Key Concept | NOOA Principle |
|---|---|---|---|
| 01 | [`01_first_generation_method.dart`](./01_first_generation_method.dart) | Defining agents as classes, docstrings as prompts | Principle 1 (Class-as-agent) |
| 02 | [`02_structured_output.dart`](./02_structured_output.dart) | Strongly typed model response parsing | Principle 1 (Typed I/O) |
| 03 | [`03_tool_usage.dart`](./03_tool_usage.dart) | Action registration, tool calls & explicit state | Principle 5 (Explicit State) |
| 04 | [`04_tracing.dart`](./04_tracing.dart) | Observability, telemetry & JSONL export | Telemetry & Auditing |
| 05 | [`05_strategies.dart`](./05_strategies.dart) | ReAct, CodeAct, PlanAndSolve strategies | Principle 4 (Loop Engineering) |
| 06 | [`06_pass_by_reference.dart`](./06_pass_by_reference.dart) | Handling large datasets using ObjectHeap (`#ref_xxx`) | Principle 2 (Pass-by-Reference) |
| 07 | [`07_cognitive_memory.dart`](./07_cognitive_memory.dart) | ACT-R activation, Ebbinghaus decay & owner gating | `nooa-memory` Subsystem |
| 08 | [`08_mcp_integration.dart`](./08_mcp_integration.dart) | Model Context Protocol (MCP) tool discovery & calls | Principle 6 (Harness APIs) |
| 09 | [`09_checkpoint_recovery.dart`](./09_checkpoint_recovery.dart) | SQLite state persistence, pause, and crash recovery | `nooa.storage` Subsystem |
| 10 | [`10_multi_agent_orchestration.dart`](./10_multi_agent_orchestration.dart) | Subagent spawning & multi-agent pipeline delegation | Multi-Agent Systems |
| — | [`run_benchmarks.dart`](./run_benchmarks.dart) | SWE-bench Verified & MobileBench evaluation runner | `nooa.bench` Evaluation Suite |

---

## Running the Examples

You can execute any tutorial script using the standard Dart CLI:

```bash
cd mobi_nooa_core

# Run tutorial 01
dart run example/01_first_generation_method.dart

# Run tutorial 06 (Pass-by-reference)
dart run example/06_pass_by_reference.dart

# Run tutorial 07 (Cognitive Memory)
dart run example/07_cognitive_memory.dart

# Run full benchmark evaluation runner
dart run example/run_benchmarks.dart
```
