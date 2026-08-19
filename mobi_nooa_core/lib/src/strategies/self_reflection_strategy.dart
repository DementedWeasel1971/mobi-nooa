import 'dart:async';
import 'execution_strategy.dart';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';
import '../loop/step_event.dart';

/// Self-Reflection Strategy: Evaluates previous errors, reflects on failure causes, and formulates correction plans.
class SelfReflectionStrategy implements ExecutionStrategy {
  @override
  final String name = 'SelfReflection';

  @override
  final String description =
      'Iterative self-critique evaluating errors and refining actions before concluding.';

  @override
  String buildStrategyPrompt(NooaAgent agent) {
    return '''
Whenever an error occurs or a test fails:
1. Reflection: Explicitly diagnose the root cause of why the previous action failed.
2. Correction Plan: Formulate a revised approach addressing the exact root cause.
3. Execution: Take the corrected action.
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

    return StrategyStepResult.finish(modelResponse.text.trim());
  }
}
