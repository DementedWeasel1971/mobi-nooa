import '../heap/object_heap.dart';
import '../models/model_client.dart';
import '../harness/harness_api.dart';
import '../tracing/tracer.dart';

/// Execution context provided to a [NooaAgent] during an agentic run.
class AgentContext {
  /// Live heap for pass-by-reference object management.
  final ObjectHeap heap;

  /// Model client used to generate responses and dynamic action completions.
  final ModelClient model;

  /// System and mobile device harness APIs.
  final HarnessApi harness;

  /// Tracing and telemetry collector.
  final Tracer tracer;

  /// Optional parent agent context if running as a subagent.
  final AgentContext? parentContext;

  /// Shared variables and key-value attributes.
  final Map<String, dynamic> environment;

  /// Whether cancellation was requested.
  bool isCancelled = false;

  AgentContext({
    required this.heap,
    required this.model,
    required this.harness,
    required this.tracer,
    this.parentContext,
    Map<String, dynamic>? environment,
  }) : environment = environment ?? {};

  /// Creates a scoped child context for a subagent.
  AgentContext createSubContext({
    String? subagentName,
    ModelClient? modelOverride,
  }) {
    return AgentContext(
      heap: heap, // Shared live object heap so parent & child can exchange live object handles
      model: modelOverride ?? model,
      harness: harness,
      tracer: tracer.createChildTracer(subagentName ?? 'SubAgent'),
      parentContext: this,
      environment: Map.from(environment),
    );
  }
}
