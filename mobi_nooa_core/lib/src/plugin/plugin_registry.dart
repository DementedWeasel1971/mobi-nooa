import 'dart:async';
import '../agent/reflector.dart';
import '../models/model_client.dart';
import 'agent_plugin.dart';
import 'plugin_context.dart';

/// Central registry managing plugin lifecycles, action collections, and event dispatches.
class PluginRegistry {
  final Map<String, AgentPlugin> _plugins = {};

  /// Read-only view of all registered plugins.
  List<AgentPlugin> get plugins => _plugins.values.toList();

  /// Registers a plugin.
  void register(AgentPlugin plugin) {
    _plugins[plugin.name] = plugin;
  }

  /// Unregisters a plugin by [name].
  AgentPlugin? unregister(String name) {
    return _plugins.remove(name);
  }

  /// Retrieves a registered plugin by [name].
  T? getPlugin<T extends AgentPlugin>(String name) {
    final p = _plugins[name];
    if (p is T) return p;
    return null;
  }

  /// Initializes all enabled plugins with the provided [context].
  Future<void> initializeAll(PluginContext context) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.initialize(context);
      }
    }
  }

  /// Disposes all registered plugins.
  Future<void> disposeAll() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
    _plugins.clear();
  }

  /// Aggregates all [ActionMetadata]s contributed by enabled plugins.
  List<ActionMetadata> collectActions() {
    final actions = <ActionMetadata>[];
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        actions.addAll(plugin.providedActions);
      }
    }
    return actions;
  }

  /// Dispatches [onBeforeStep] hook across all active plugins.
  Future<void> dispatchBeforeStep(int stepIndex, List<ModelMessage> messages) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.onBeforeStep(stepIndex, messages);
      }
    }
  }

  /// Dispatches [onAfterStep] hook across all active plugins.
  Future<void> dispatchAfterStep(int stepIndex, ModelResponse response) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.onAfterStep(stepIndex, response);
      }
    }
  }

  /// Dispatches [onBeforeToolExecution] hook across all active plugins.
  Future<void> dispatchBeforeToolExecution(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.onBeforeToolExecution(toolName, arguments);
      }
    }
  }

  /// Dispatches [onAfterToolExecution] hook across all active plugins.
  Future<void> dispatchAfterToolExecution(
    String toolName,
    Map<String, dynamic> arguments,
    dynamic result,
  ) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.onAfterToolExecution(toolName, arguments, result);
      }
    }
  }

  /// Dispatches [onAgentFinished] hook across all active plugins.
  Future<void> dispatchAgentFinished(String result) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.onAgentFinished(result);
      }
    }
  }

  /// Dispatches [onError] hook across all active plugins.
  Future<void> dispatchError(Object error, StackTrace stackTrace) async {
    for (final plugin in _plugins.values) {
      if (plugin.isEnabled) {
        await plugin.onError(error, stackTrace);
      }
    }
  }
}
