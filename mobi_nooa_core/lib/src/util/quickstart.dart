import '../agent/nooa_agent.dart';
import '../agent/agent_context.dart';
import '../agent/operating_mode.dart';
import '../heap/object_heap.dart';
import '../harness/harness_api.dart';
import '../models/model_client.dart';
import '../models/mock_client.dart';
import '../tracing/tracer.dart';
import '../security/permission_manager.dart';
import '../plugin/plugin_registry.dart';
import '../session/session_event_log.dart';

/// Quickstart builder utility for creating and initializing mobi-nooa agents in 3 lines.
class Quickstart {
  /// Spawns a fully wired agent attached to an active context.
  static T createAgent<T extends NooaAgent>(
    T Function() agentConstructor, {
    ModelClient? model,
    HarnessApi? harness,
    ObjectHeap? heap,
    String? tracerName,
    PermissionManager? permissionManager,
    PluginRegistry? plugins,
    SessionEventLog? sessionLog,
    AgentOperatingMode operatingMode = AgentOperatingMode.autonomous,
  }) {
    final agent = agentConstructor();
    final activeHeap = heap ?? ObjectHeap();
    final activeHarness = harness ?? HarnessApi();
    final activeModel = model ?? MockModelClient();
    final activeTracer = Tracer(tracerName ?? agent.name);

    final ctx = AgentContext(
      heap: activeHeap,
      model: activeModel,
      harness: activeHarness,
      tracer: activeTracer,
      permissionManager: permissionManager,
      plugins: plugins,
      sessionLog: sessionLog,
      operatingMode: operatingMode,
    );

    agent.attachContext(ctx);
    return agent;
  }
}
