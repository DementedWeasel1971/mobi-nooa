import 'dart:async';
import '../agent/reflector.dart';
import '../models/model_client.dart';
import '../security/permission_manager.dart';
import 'agent_plugin.dart';
import 'plugin_context.dart';

/// Plugin that provides dynamic, lambda-based tool/action registration at runtime.
class DynamicToolPlugin extends AgentPlugin {
  final List<ActionMetadata> _actions = [];

  DynamicToolPlugin({
    String name = 'dynamic_tools',
    String version = '1.0.0',
    String description = 'Dynamic runtime action registration plugin',
  }) : super(
          name: name,
          version: version,
          description: description,
        );

  /// Registers an action dynamically.
  void registerAction({
    required String name,
    required String description,
    List<ToolParameter> parameters = const [],
    required Future<dynamic> Function(Map<String, dynamic> args) invoker,
  }) {
    _actions.add(
      ActionMetadata(
        name: name,
        description: description,
        parameters: parameters,
        invoker: invoker,
      ),
    );
  }

  @override
  List<ActionMetadata> get providedActions => List.unmodifiable(_actions);
}

/// Plugin that records structured telemetry for loop steps and tool invocations.
class TelemetryLoggerPlugin extends AgentPlugin {
  final List<Map<String, dynamic>> records = [];
  final void Function(Map<String, dynamic> record)? onLog;

  TelemetryLoggerPlugin({
    this.onLog,
    String name = 'telemetry_logger',
  }) : super(
          name: name,
          version: '1.0.0',
          description: 'Captures and streams telemetry events for steps and tool executions',
        );

  void _record(String event, Map<String, dynamic> data) {
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'event': event,
      ...data,
    };
    records.add(entry);
    if (onLog != null) {
      onLog!(entry);
    }
  }

  @override
  Future<void> onBeforeStep(int stepIndex, List<ModelMessage> messages) async {
    _record('beforeStep', {'stepIndex': stepIndex, 'messageCount': messages.length});
  }

  @override
  Future<void> onAfterStep(int stepIndex, ModelResponse response) async {
    _record('afterStep', {
      'stepIndex': stepIndex,
      'textLength': response.text.length,
      'hasReasoning': response.hasReasoning,
      'toolCallCount': response.toolCalls.length,
      'totalTokens': response.usage.totalTokens,
    });
  }

  @override
  Future<void> onBeforeToolExecution(String toolName, Map<String, dynamic> arguments) async {
    _record('beforeToolExecution', {'toolName': toolName, 'arguments': arguments});
  }

  @override
  Future<void> onAfterToolExecution(
    String toolName,
    Map<String, dynamic> arguments,
    dynamic result,
  ) async {
    _record('afterToolExecution', {
      'toolName': toolName,
      'arguments': arguments,
      'resultPreview': result.toString(),
    });
  }
}

/// Plugin that intercepts tool calls and validates them against security rules.
class AuditSecurityPlugin extends AgentPlugin {
  PluginContext? _context;
  final List<String> blockedAttempts = [];

  AuditSecurityPlugin({
    String name = 'audit_security',
  }) : super(
          name: name,
          version: '1.0.0',
          description: 'Audits tool executions and intercepts forbidden patterns',
        );

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
  }

  @override
  Future<void> onBeforeToolExecution(String toolName, Map<String, dynamic> arguments) async {
    final permManager = _context?.permissionManager;
    if (permManager != null) {
      final decision = await permManager.checkPermission(toolName, arguments);
      if (!decision.isAllowed) {
        blockedAttempts.add('$toolName: ${decision.reason}');
        throw SecurityException(
          'Blocked by AuditSecurityPlugin: ${decision.reason}',
          actionName: toolName,
          arguments: arguments,
        );
      }
    }
  }
}
