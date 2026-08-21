/// mobi-nooa Core Engine: Mobile Object-Oriented Agents
/// Faithful Dart/Kotlin adaptation of NVIDIA NOOA (labs-OO-Agents, arXiv:2607.20709)
/// and DeepSeek Harness (dsh) plugin-first architecture.
library mobi_nooa_core;

// Agent Core
export 'src/agent/annotations.dart';
export 'src/agent/agent_context.dart';
export 'src/agent/nooa_agent.dart';
export 'src/agent/general_mobile_agent.dart';
export 'src/agent/autonomous_device_agent.dart';
export 'src/agent/data_analyst_agent.dart';
export 'src/agent/autonomous_coding_agent.dart';
export 'src/agent/operating_mode.dart';
export 'src/agent/reflector.dart';

// Object Heap & Pass-by-Reference (Principle 2)
export 'src/heap/object_reference.dart';
export 'src/heap/bounded_preview.dart';
export 'src/heap/object_heap.dart';

// Code as Action (CodeAct - Principle 3)
export 'src/engine/sandboxed_environment.dart';
export 'src/engine/ast_evaluator.dart';
export 'src/engine/code_act_engine.dart';

// Programmable Loop Engineering (Principle 4)
export 'src/loop/loop_config.dart';
export 'src/loop/step_event.dart';
export 'src/loop/agent_loop.dart';

// Model Clients & LLM Adapters
export 'src/models/model_client.dart';
export 'src/models/mock_client.dart';
export 'src/models/gemini_client.dart';
export 'src/models/openai_client.dart';
export 'src/models/anthropic_client.dart';
export 'src/models/ollama_client.dart';
export 'src/models/on_device_client.dart';
export 'src/models/nvidia_client.dart';
export 'src/models/deepseek_client.dart';
export 'src/models/fallback_cascade_client.dart';

// Model-Callable Harness APIs (Principle 6)
export 'src/harness/harness_api.dart';
export 'src/harness/device_harness.dart';
export 'src/harness/filesystem_harness.dart';
export 'src/harness/network_harness.dart';
export 'src/harness/memory_harness.dart';
export 'src/harness/mcp_harness.dart';
export 'src/harness/sqlite_harness.dart';

// BenchAgent & Developer Coding Tools
export 'src/agent/bench_agent.dart';
export 'src/tools/file_editor_tool.dart';
export 'src/tools/shell_tool.dart';
export 'src/tools/code_search_tool.dart';

// AST Security, Tiered Permissions & Guardrails
export 'src/security/ast_guardrails.dart';
export 'src/security/permission_policy.dart';
export 'src/security/permission_manager.dart';

// Plugin System & Service Seam (DeepSeek Harness Architecture)
export 'src/plugin/agent_plugin.dart';
export 'src/plugin/plugin_context.dart';
export 'src/plugin/plugin_registry.dart';
export 'src/plugin/built_in_plugins.dart';

// Append-Only Session Event Log, Replay & Forking (DeepSeek Harness Architecture)
export 'src/session/session_event.dart';
export 'src/session/session_event_log.dart';

// Memory & Cognitive ACT-R Activation (nooa-memory)
export 'src/memory/act_r_memory.dart';
export 'src/memory/owner_gated_memory.dart';

// Storage & Checkpoint Persistence (nooa.storage)
export 'src/storage/agent_checkpoint.dart';
export 'src/storage/state_storage_manager.dart';

// Skills & Procedural Knowledge (nooa-skills)
export 'src/skills/skill.dart';
export 'src/skills/skill_store.dart';
export 'src/skills/skill_harness.dart';
export 'src/skills/skill_prompt_enhancer.dart';

// Execution Strategies (nooa.strategies)
export 'src/strategies/execution_strategy.dart';
export 'src/strategies/react_strategy.dart';
export 'src/strategies/code_act_strategy.dart';
export 'src/strategies/plan_and_solve_strategy.dart';
export 'src/strategies/self_reflection_strategy.dart';

// Benchmarking & Evaluation Suite (nooa.bench & SWE-bench)
export 'src/bench/benchmark_suite.dart';
export 'src/bench/swe_bench_runner.dart';
export 'src/bench/mobile_bench_runner.dart';

// Platform bridge dispatcher (pure-Dart, no Flutter dependency)
export 'src/bridge/agent_bridge_dispatcher.dart';

// Utilities & Quickstart (nooa.util)
export 'src/util/quickstart.dart';
export 'src/util/prompt_builder.dart';

// Tracing & Telemetry
export 'src/tracing/trace_event.dart';
export 'src/tracing/tracer.dart';

// Resource Governor & Adaptive Load Balancer (nooa-governor)
export 'src/governor/resource_governor.dart';
