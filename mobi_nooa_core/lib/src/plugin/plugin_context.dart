import '../agent/nooa_agent.dart';
import '../agent/agent_context.dart';
import '../heap/object_heap.dart';
import '../harness/harness_api.dart';
import '../tracing/tracer.dart';
import '../security/permission_manager.dart';

/// Execution environment passed to [AgentPlugin] during lifecycle events.
class PluginContext {
  final NooaAgent agent;
  final AgentContext agentContext;
  final PermissionManager? permissionManager;
  final Map<String, dynamic> config;

  PluginContext({
    required this.agent,
    required this.agentContext,
    this.permissionManager,
    this.config = const {},
  });

  ObjectHeap get heap => agentContext.heap;
  HarnessApi get harness => agentContext.harness;
  Tracer get tracer => agentContext.tracer;
}
