import 'dart:async';
import 'execution_strategy.dart';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';
import '../loop/step_event.dart';

/// Plan-and-Solve Strategy: Decomposing a complex user goal into ordered subgoals before execution.
class PlanAndSolveStrategy implements ExecutionStrategy {
  @override
  final String name = 'PlanAndSolve';

  @override
  final String description =
      'Explicit planning phase decomposing the goal into subtasks, followed by sequential execution.';

  @override
  String buildStrategyPrompt(NooaAgent agent) {
    return '''
Phase 1: First, produce a numbered plan of concise subgoals to solve the task.
Phase 2: Execute each step methodically, verifying intermediate results before moving forward.
When all steps are satisfied, state "All plan steps completed:" followed by your final result.
''';
  }

  @override
  Future<StrategyStepResult> processResponse({
    required NooaAgent agent,
    required ModelResponse modelResponse,
    required List<StepExecution> history,
  }) async {
    if (modelResponse.hasToolCalls) {
      return StrategyStepResult.continueLoop(
        thought: modelResponse.text,
        toolCalls: modelResponse.toolCalls,
      );
    }

    final text = modelResponse.text.trim();
    if (text.contains('All plan steps completed:') || text.contains('Final Answer:')) {
      return StrategyStepResult.finish(text);
    }

    // If history is small (e.g. initial plan produced), continue loop to execute
    if (history.length <= 1 && text.contains('1.') && text.contains('2.')) {
      return StrategyStepResult.continueLoop(thought: 'Plan formulated:\n$text');
    }

    return StrategyStepResult.finish(text);
  }
}
