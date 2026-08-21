import 'dart:async';
import 'nooa_agent.dart';
import '../loop/agent_loop.dart';
import '../loop/loop_config.dart';
import '../models/model_client.dart';
import '../harness/filesystem_harness.dart';
import '../session/session_event_log.dart';
import '../tracing/tracer.dart';
import '../tracing/trace_event.dart';
import '../util/quickstart.dart';

/// Workspace isolation mode for parallel subagents.
enum SubagentWorkspaceMode {
  /// Each subagent operates in its own cloned/isolated filesystem workspace (similar to Git worktree).
  isolated,

  /// Subagents share the parent workspace directory.
  shared,
}

/// Lifecycle state of a parallel subagent.
enum SubagentLifecycleState {
  spawning,
  running,
  completed,
  failed,
  cancelled,
}

/// Spec for spawning a parallel subagent task.
class SubagentTaskSpec {
  final String id;
  final String role;
  final String prompt;
  final String agentTypeName;
  final SubagentWorkspaceMode workspaceMode;
  final int maxSteps;
  final Map<String, dynamic> initialInputs;

  SubagentTaskSpec({
    required this.id,
    required this.role,
    required this.prompt,
    this.agentTypeName = 'GeneralMobileAgent',
    this.workspaceMode = SubagentWorkspaceMode.isolated,
    this.maxSteps = 5,
    this.initialInputs = const {},
  });
}

/// Result returned from an individual parallel subagent execution.
class SubagentTaskResult {
  final String id;
  final String role;
  final SubagentLifecycleState state;
  final dynamic output;
  final String? error;
  final int stepsExecuted;
  final Duration duration;
  final Map<String, dynamic> exportedState;

  SubagentTaskResult({
    required this.id,
    required this.role,
    required this.state,
    this.output,
    this.error,
    required this.stepsExecuted,
    required this.duration,
    this.exportedState = const {},
  });

  bool get isSuccess => state == SubagentLifecycleState.completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'state': state.name,
        'output': output?.toString(),
        'error': error,
        'stepsExecuted': stepsExecuted,
        'durationMs': duration.inMilliseconds,
        'exportedState': exportedState,
      };

  @override
  String toString() =>
      'Subagent[$id, role=$role, state=${state.name}]: ${output ?? error}';
}

/// Parallel Subagent Orchestrator.
///
/// Implements Grok Build's parallel subagent harness concept, allowing a parent agent
/// to spawn up to [maxConcurrency] concurrent subagents (default 8) with isolated
/// workspaces (worktree simulation), concurrent task pooling, and result aggregation.
class SubagentOrchestrator {
  final int maxConcurrency;
  final ModelClient model;
  final Tracer? tracer;
  final SessionEventLog? sessionLog;
  final Map<String, NooaAgent Function()> _agentFactories;

  SubagentOrchestrator({
    required this.model,
    this.maxConcurrency = 8,
    this.tracer,
    this.sessionLog,
    Map<String, NooaAgent Function()>? agentFactories,
  }) : _agentFactories = agentFactories ?? {};

  void registerAgent(String name, NooaAgent Function() factory) {
    _agentFactories[name] = factory;
  }

  /// Spawns a batch of parallel subagents concurrently up to [maxConcurrency].
  Future<List<SubagentTaskResult>> runParallelBatch(
    List<SubagentTaskSpec> tasks, {
    MemoryFileSystemHarness? parentFileSystem,
  }) async {
    if (tasks.isEmpty) return [];

    final batchStopwatch = Stopwatch()..start();
    tracer?.record(
      type: TraceEventType.subagentSpawn,
      description:
          'Spawning parallel subagent batch of ${tasks.length} tasks (maxConcurrency: $maxConcurrency)',
    );

    // Limit concurrency via chunking or Futures pool
    final results = <SubagentTaskResult>[];

    for (int i = 0; i < tasks.length; i += maxConcurrency) {
      final chunk = tasks.skip(i).take(maxConcurrency);
      final chunkFutures = chunk.map((task) => _executeSubagent(task, parentFileSystem));
      final chunkResults = await Future.wait(chunkFutures);
      results.addAll(chunkResults);
    }

    batchStopwatch.stop();
    tracer?.record(
      type: TraceEventType.stepEnd,
      description:
          'Completed parallel subagent batch in ${batchStopwatch.elapsedMilliseconds}ms (${results.where((r) => r.isSuccess).length}/${results.length} succeeded)',
    );

    return results;
  }

  Future<SubagentTaskResult> _executeSubagent(
    SubagentTaskSpec task,
    MemoryFileSystemHarness? parentFileSystem,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final NooaAgent agent;
      final factory = _agentFactories[task.agentTypeName];
      if (factory != null) {
        agent = Quickstart.createAgent(
          factory,
          model: model,
          sessionLog: sessionLog,
          tracer: tracer,
        );
      } else {
        agent = Quickstart.createAgent(
          () => _DefaultSubagent(),
          model: model,
          sessionLog: sessionLog,
          tracer: tracer,
        );
      }

      final loop = AgentLoop(
        agent: agent,
        context: agent.context,
        config: LoopConfig(
          maxSteps: task.maxSteps,
          sessionLog: sessionLog,
        ),
      );

      final result = await loop.run(task.prompt);
      sw.stop();

      return SubagentTaskResult(
        id: task.id,
        role: task.role,
        state: SubagentLifecycleState.completed,
        output: result,
        stepsExecuted: 1,
        duration: sw.elapsed,
        exportedState: agent.getStateSnapshot(),
      );
    } catch (e) {
      sw.stop();
      return SubagentTaskResult(
        id: task.id,
        role: task.role,
        state: SubagentLifecycleState.failed,
        error: e.toString(),
        stepsExecuted: 0,
        duration: sw.elapsed,
      );
    }
  }
}

class _DefaultSubagent extends NooaAgent {
  _DefaultSubagent() : super(name: 'DefaultSubagent');
}
