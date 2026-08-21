import '../agent/operating_mode.dart';
import '../security/permission_manager.dart';
import '../plugin/plugin_registry.dart';
import '../session/session_event_log.dart';

/// Loop mode determines whether actions are executed via direct Tool Calling or CodeAct scripts.
enum ExecutionMode {
  toolCalling,
  codeAct,
  hybrid,
}

/// Configuration settings for programmable agent loops.
class LoopConfig {
  final int maxSteps;
  final double temperature;
  final ExecutionMode executionMode;
  final bool enablePassByReference;
  final bool autoSummarizeHeap;
  final Duration stepTimeout;
  final int maxConsecutiveErrors;
  final AgentOperatingMode operatingMode;
  final PermissionManager? permissionManager;
  final PluginRegistry? plugins;
  final SessionEventLog? sessionLog;

  const LoopConfig({
    this.maxSteps = 10,
    this.temperature = 0.2,
    this.executionMode = ExecutionMode.hybrid,
    this.enablePassByReference = true,
    this.autoSummarizeHeap = true,
    this.stepTimeout = const Duration(seconds: 90),
    this.maxConsecutiveErrors = 3,
    this.operatingMode = AgentOperatingMode.autonomous,
    this.permissionManager,
    this.plugins,
    this.sessionLog,
  });
}
