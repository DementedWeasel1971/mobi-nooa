import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 10: Multi-Agent Orchestration & Subagent Spawning
///
/// Demonstrates an orchestrator agent delegating specialized subtasks to worker agents.
class WorkerAgent extends NooaAgent {
  WorkerAgent({String? name})
      : super(
          name: name ?? 'WorkerAgent',
          role: 'Specialized Task Worker',
          description: 'Performs data transformations.',
        );
}

class OrchestratorAgent extends NooaAgent {
  OrchestratorAgent()
      : super(
          name: 'OrchestratorAgent',
          role: 'Team Lead Agent',
          description: 'Orchestrates multiple worker agents to solve complex pipelines.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'delegateTask',
      description: 'Spawns a worker agent to handle a subtask.',
      parameters: const [
        ToolParameter(name: 'taskName', type: 'string', description: 'Name of the subtask', required: true),
      ],
      returnType: 'String',
      invoker: (args) async {
        final taskName = args['taskName'] as String;
        final worker = WorkerAgent(name: 'Worker_${taskName}');
        return await spawnSubagent(
          subagent: worker,
          task: 'Execute subtask: $taskName',
        );
      },
    );
  }
}

Future<void> main() async {
  print('=== mobi-nooa Tutorial 10: Multi-Agent Orchestration ===\n');

  final orchestratorModel = MockModelClient();
  orchestratorModel.queueToolCall(
    toolName: 'delegateTask',
    arguments: {'taskName': 'parse_dataset'},
    thought: 'Delegating data parsing to worker agent.',
  );
  orchestratorModel.queueToolCall(
    toolName: 'delegateTask',
    arguments: {'taskName': 'compress_logs'},
    thought: 'Delegating log compression to worker agent.',
  );
  orchestratorModel.queueText('All 2 subtasks completed across worker team.');

  final orchestrator = Quickstart.createAgent(
    () => OrchestratorAgent(),
    model: orchestratorModel,
  );

  final pipelineResult = await orchestrator.ellipsis<String>(
    'Run data pipeline with parsing and log compression.',
  );

  print('Orchestrator Result:\n$pipelineResult');
}
