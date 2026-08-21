import '../heap/object_heap.dart';
import '../models/model_client.dart';
import '../harness/harness_api.dart';
import '../tracing/tracer.dart';
import '../security/permission_manager.dart';
import '../plugin/plugin_registry.dart';
import '../session/session_event_log.dart';
import 'operating_mode.dart';

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

  /// Security and authorization permission manager (DeepSeek Harness tiered security).
  final PermissionManager permissionManager;

  /// Plugin registry for dynamic tools, harnesses, middleware, and interceptors.
  final PluginRegistry plugins;

  /// Unified append-only session event log (DeepSeek Harness event stream & forking).
  final SessionEventLog? sessionLog;

  /// Operational mode governing autonomous, supervised, or audit behavior.
  final AgentOperatingMode operatingMode;

  /// Whether cancellation was requested.
  bool isCancelled = false;

  AgentContext({
    required this.heap,
    required this.model,
    required this.harness,
    required this.tracer,
    this.parentContext,
    Map<String, dynamic>? environment,
    PermissionManager? permissionManager,
    PluginRegistry? plugins,
    this.sessionLog,
    this.operatingMode = AgentOperatingMode.autonomous,
  })  : environment = environment ?? {},
        permissionManager = permissionManager ?? PermissionManager(),
        plugins = plugins ?? PluginRegistry();

  /// Creates a scoped child context for a subagent.
  AgentContext createSubContext({
    String? subagentName,
    ModelClient? modelOverride,
    PermissionManager? permissionManagerOverride,
    AgentOperatingMode? operatingModeOverride,
  }) {
    return AgentContext(
      heap: heap, // Shared live object heap so parent & child can exchange live object handles
      model: modelOverride ?? model,
      harness: harness,
      tracer: tracer.createChildTracer(subagentName ?? 'SubAgent'),
      parentContext: this,
      environment: Map.from(environment),
      permissionManager: permissionManagerOverride ?? permissionManager,
      plugins: plugins,
      sessionLog: sessionLog,
      operatingMode: operatingModeOverride ?? operatingMode,
    );
  }
}
