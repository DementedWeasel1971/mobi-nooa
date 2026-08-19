import 'dart:async';
import 'execution_strategy.dart';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';
import '../loop/step_event.dart';
import '../engine/code_act_engine.dart';

/// CodeAct Strategy: Emitting executable code blocks directly targeting live heap objects.
class CodeActStrategy implements ExecutionStrategy {
  @override
  final String name = 'CodeAct';

  @override
  final String description =
      'Executes multi-statement code blocks against live ObjectHeap handles and harness APIs.';

  @override
  String buildStrategyPrompt(NooaAgent agent) {
    return '''
Solve the user task by writing executable code snippets in ```dart or ```python blocks.
You have direct access to:
- `heap.get("#ref_xxx")` to interact with live objects.
- Built-in functions: `sum()`, `avg()`, `min()`, `max()`, `len()`, `jsonEncode()`, `jsonDecode()`.
- Harness APIs: `device`, `fs`, `network`, `memory`.
- Return values and large datasets will automatically be wrapped as `#ref_xxx` handles in ObjectHeap.
''';
  }

  @override
  Future<StrategyStepResult> processResponse({
    required NooaAgent agent,
    required ModelResponse modelResponse,
    required List<StepExecution> history,
  }) async {
    final code = CodeActEngine.extractCodeBlock(modelResponse.text);
    if (code.isNotEmpty && code != modelResponse.text.trim()) {
      return StrategyStepResult.continueLoop(
        thought: modelResponse.text,
        codeSnippet: code,
      );
    }

    if (modelResponse.hasToolCalls) {
      return StrategyStepResult.continueLoop(
        thought: modelResponse.text,
        toolCalls: modelResponse.toolCalls,
      );
    }

    return StrategyStepResult.finish(modelResponse.text.trim());
  }
}
