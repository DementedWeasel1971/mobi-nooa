import 'dart:async';
import '../agent/reflector.dart';
import '../models/model_client.dart';
import 'plugin_context.dart';

/// Base contract for plugins in the mobi-nooa runtime.
///
/// Implements the "Everything is a plugin" design pattern (inspired by DeepSeek Harness / Cordis).
/// Plugins can inject actions/tools, provide harnesses, intercept loop steps, audit security,
/// and stream telemetry.
abstract class AgentPlugin {
  final String name;
  final String version;
  final String description;
  bool isEnabled;

  AgentPlugin({
    required this.name,
    this.version = '1.0.0',
    this.description = '',
    this.isEnabled = true,
  });

  /// Called when the plugin is initialized within an agent context.
  Future<void> initialize(PluginContext context) async {}

  /// Called when the agent context or plugin is disposed.
  Future<void> dispose() async {}

  /// Actions/tools contributed dynamically by this plugin to the host agent.
  List<ActionMetadata> get providedActions => const [];

  /// Intercept before an LLM step is executed.
  Future<void> onBeforeStep(int stepIndex, List<ModelMessage> messages) async {}

  /// Intercept after an LLM step returns a response.
  Future<void> onAfterStep(int stepIndex, ModelResponse response) async {}

  /// Intercept before a tool is invoked.
  Future<void> onBeforeToolExecution(String toolName, Map<String, dynamic> arguments) async {}

  /// Intercept after a tool has executed and returned a result.
  Future<void> onAfterToolExecution(
    String toolName,
    Map<String, dynamic> arguments,
    dynamic result,
  ) async {}

  /// Called when the agent successfully finishes execution.
  Future<void> onAgentFinished(String result) async {}

  /// Called when an error occurs during execution.
  Future<void> onError(Object error, StackTrace stackTrace) async {}
}
