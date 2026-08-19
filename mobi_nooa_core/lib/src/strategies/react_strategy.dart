import 'dart:async';
import 'execution_strategy.dart';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';
import '../loop/step_event.dart';

/// ReAct Strategy: Explicit Thought -> Action -> Observation reasoning loop.
class ReActStrategy implements ExecutionStrategy {
  @override
  final String name = 'ReAct';

  @override
  final String description =
      'Step-by-step reasoning cycle alternating between Thought, Action, and Observation.';

  @override
  String buildStrategyPrompt(NooaAgent agent) {
    return '''
Use the following format for each step:
Thought: Think step-by-step about what to do next based on previous observations and current state.
Action: Invoke an available tool with required parameters.
Observation: The tool execution result will be returned here.
... (Repeat Thought/Action/Observation as needed)
Thought: I have gathered all necessary information to solve the goal.
Final Answer: The definitive, concise final conclusion.
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
    if (text.contains('Final Answer:')) {
      final answer = text.split('Final Answer:').last.trim();
      return StrategyStepResult.finish(answer, thought: text);
    }

    return StrategyStepResult.finish(text);
  }
}
