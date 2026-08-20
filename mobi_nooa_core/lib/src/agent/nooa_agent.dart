import 'dart:async';
import 'reflector.dart';
import 'agent_context.dart';
import '../models/model_client.dart';
import '../loop/agent_loop.dart';
import '../loop/loop_config.dart';
import '../tracing/trace_event.dart';

/// Base class for all Mobile Object-Oriented Agents (mobi-nooa).
///
/// Implements NOOA's unifying philosophy:
/// - Class defines the Agent.
/// - Fields represent explicit state.
/// - Methods represent capabilities/actions.
/// - Docstrings and type annotations serve as prompts and tool contracts.
/// - Methods with `ellipsis(...)` invoke dynamic LLM-driven loops.
abstract class NooaAgent {
  final String name;
  final String role;
  final String description;
  final String customPromptInstructions;

  /// Explicit state container for the agent (NOOA Principle 5).
  final Map<String, dynamic> _state = {};
  final List<ActionMetadata> _actions = [];
  final StreamController<Map<String, dynamic>> _stateChangeController =
      StreamController<Map<String, dynamic>>.broadcast();

  AgentContext? _context;

  NooaAgent({
    required this.name,
    this.role = '',
    this.description = '',
    this.customPromptInstructions = '',
  }) {
    initAgent();
  }

  /// Hook for subclasses to declare actions, state, and tools.
  void initAgent() {}

  /// Current execution context (model, heap, harness, tracer).
  AgentContext get context {
    if (_context == null) {
      throw StateError('Agent "$name" is not attached to an AgentContext.');
    }
    return _context!;
  }

  /// Attaches an execution context to this agent.
  void attachContext(AgentContext ctx) {
    _context = ctx;
  }

  /// Stream of state changes for reactive mobile UI binding.
  Stream<Map<String, dynamic>> get onStateChanged =>
      _stateChangeController.stream;

  /// Declared actions available on this agent.
  List<ActionMetadata> get declaredActions => List.unmodifiable(_actions);

  /// Finds a declared action by its [name].
  ActionMetadata? findAction(String name) =>
      _actions.where((a) => a.name == name).firstOrNull;

  /// Registers an action on this agent.
  void registerAction({
    required String name,
    required String description,
    List<ToolParameter> parameters = const [],
    String returnType = 'dynamic',
    bool isDynamic = false,
    required Future<dynamic> Function(Map<String, dynamic> args) invoker,
  }) {
    _actions.removeWhere((a) => a.name == name);
    _actions.add(ActionMetadata(
      name: name,
      description: description,
      parameters: parameters,
      returnType: returnType,
      isDynamic: isDynamic,
      invoker: invoker,
    ));
  }

  /// Sets an explicit state variable and notifies listeners.
  void setState(String key, dynamic value) {
    _state[key] = value;
    _stateChangeController.add(Map.unmodifiable(_state));
  }

  /// Gets an explicit state variable.
  dynamic getState(String key) => _state[key];

  /// Returns a snapshot map of the agent's explicit state.
  Map<String, dynamic> getStateSnapshot() => Map.unmodifiable(_state);

  /// Restores state from a snapshot map.
  void restoreState(Map<String, dynamic> snapshot) {
    _state.clear();
    _state.addAll(snapshot);
    _stateChangeController.add(Map.unmodifiable(_state));
  }

  /// The NOOA Ellipsis (`...`) pattern:
  /// Invokes a dynamic LLM-driven agentic loop to complete a task.
  Future<T> ellipsis<T>(
    String goalOrPrompt, {
    Map<String, dynamic> inputs = const {},
    int maxSteps = 10,
    double temperature = 0.2,
  }) async {
    final loop = AgentLoop(
      agent: this,
      context: context,
      config: LoopConfig(
        maxSteps: maxSteps,
        temperature: temperature,
      ),
    );

    final result = await loop.run(goalOrPrompt, inputs: inputs);
    return result as T;
  }

  /// Spawns and delegates a subtask to a subagent (NOOA Subagent Orchestration).
  Future<dynamic> spawnSubagent({
    required NooaAgent subagent,
    required String task,
    Map<String, dynamic> inputs = const {},
    ModelClient? modelOverride,
  }) async {
    final subContext = context.createSubContext(
      subagentName: subagent.name,
      modelOverride: modelOverride,
    );
    subagent.attachContext(subContext);

    context.tracer.record(
      type: TraceEventType.subagentSpawn,
      description: 'Spawned subagent ${subagent.name} for task: $task',
      data: {'subagent': subagent.name, 'task': task, 'inputs': inputs},
    );

    return await subagent.ellipsis(task, inputs: inputs);
  }

  /// Disposes streams and resources.
  void dispose() {
    _stateChangeController.close();
  }
}
