import 'dart:async';
import 'dart:convert';
import 'agent_plugin.dart';
import '../models/model_client.dart';

/// Lifecycle hook trigger events conforming to Grok Build's hook system.
enum HookEventType {
  preStep,
  postStep,
  preToolCall,
  postToolCall,
  onError,
  onModelFallback,
}

/// A registered lifecycle hook callback definition.
class LifecycleHook {
  final String id;
  final HookEventType eventType;
  final FutureOr<void> Function(HookPayload payload) handler;

  LifecycleHook({
    required this.id,
    required this.eventType,
    required this.handler,
  });
}

/// Contextual payload delivered to a lifecycle hook.
class HookPayload {
  final HookEventType eventType;
  final String? agentName;
  final int stepIndex;
  final ToolCall? toolCall;
  final String? toolName;
  final Map<String, dynamic>? toolArguments;
  final dynamic toolResult;
  final String? error;
  final Map<String, dynamic> metadata;

  HookPayload({
    required this.eventType,
    this.agentName,
    this.stepIndex = 0,
    this.toolCall,
    this.toolName,
    this.toolArguments,
    this.toolResult,
    this.error,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'eventType': eventType.name,
        if (agentName != null) 'agentName': agentName,
        'stepIndex': stepIndex,
        if (toolCall != null) 'toolCall': toolCall!.toJson(),
        if (toolName != null) 'toolName': toolName,
        if (toolArguments != null) 'toolArguments': toolArguments,
        if (toolResult != null) 'toolResult': toolResult?.toString(),
        if (error != null) 'error': error,
        'metadata': metadata,
      };

  @override
  String toString() =>
      'HookPayload(${eventType.name}, step=$stepIndex): ${toolName ?? toolCall?.name ?? error ?? ""}';
}

/// Declarative and Programmatic Agent Lifecycle Hooks Plugin.
///
/// Implements Grok Build's `hooks.json` lifecycle interceptor system.
/// Executes registered hooks at pre/post step, tool calling, and error boundaries.
class AgentLifecycleHooksPlugin extends AgentPlugin {
  final List<LifecycleHook> _hooks = [];

  AgentLifecycleHooksPlugin()
      : super(
          name: 'AgentLifecycleHooksPlugin',
          version: '1.0.0',
          description: 'Grok Build declarative lifecycle hooks and interceptors',
        );

  /// Registers a programmatic lifecycle hook.
  void registerHook(
    HookEventType type,
    FutureOr<void> Function(HookPayload payload) handler, {
    String? id,
  }) {
    _hooks.add(
      LifecycleHook(
        id: id ?? 'hook_${_hooks.length + 1}',
        eventType: type,
        handler: handler,
      ),
    );
  }

  /// Loads declarative hooks from a `hooks.json` string or map.
  void loadFromJson(dynamic jsonConfig, {Map<String, Function>? customHandlers}) {
    Map<String, dynamic> map;
    if (jsonConfig is String) {
      map = Map<String, dynamic>.from(jsonDecode(jsonConfig) as Map);
    } else if (jsonConfig is Map) {
      map = Map<String, dynamic>.from(jsonConfig);
    } else {
      return;
    }

    final hookList = map['hooks'] as List? ?? [];
    for (final item in hookList) {
      if (item is Map) {
        final evName = item['event'] as String? ?? 'preStep';
        final hookId = item['id'] as String? ?? 'decl_${_hooks.length + 1}';
        final evType = HookEventType.values.firstWhere(
          (t) => t.name == evName,
          orElse: () => HookEventType.preStep,
        );

        final actionName = item['action'] as String?;
        final handler = customHandlers?[actionName];
        if (handler != null) {
          registerHook(evType, (payload) => handler(payload), id: hookId);
        } else {
          // Default logging hook
          registerHook(
            evType,
            (payload) {},
            id: hookId,
          );
        }
      }
    }
  }

  /// Triggers all hooks registered for [eventType].
  Future<void> trigger(HookPayload payload) async {
    final matching = _hooks.where((h) => h.eventType == payload.eventType);
    for (final hook in matching) {
      try {
        await hook.handler(payload);
      } catch (_) {}
    }
  }

  @override
  Future<void> onBeforeStep(int stepIndex, List<ModelMessage> messages) async {
    await trigger(
      HookPayload(
        eventType: HookEventType.preStep,
        stepIndex: stepIndex,
      ),
    );
  }

  @override
  Future<void> onAfterStep(int stepIndex, ModelResponse response) async {
    await trigger(
      HookPayload(
        eventType: HookEventType.postStep,
        stepIndex: stepIndex,
        toolResult: response.text,
      ),
    );
  }

  @override
  Future<void> onBeforeToolExecution(String toolName, Map<String, dynamic> arguments) async {
    await trigger(
      HookPayload(
        eventType: HookEventType.preToolCall,
        toolName: toolName,
        toolArguments: arguments,
      ),
    );
  }

  @override
  Future<void> onAfterToolExecution(
    String toolName,
    Map<String, dynamic> arguments,
    dynamic result,
  ) async {
    await trigger(
      HookPayload(
        eventType: HookEventType.postToolCall,
        toolName: toolName,
        toolArguments: arguments,
        toolResult: result,
      ),
    );
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    await trigger(
      HookPayload(
        eventType: HookEventType.onError,
        error: error.toString(),
      ),
    );
  }
}
