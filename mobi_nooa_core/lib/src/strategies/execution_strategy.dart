import 'dart:async';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';
import '../loop/step_event.dart';

/// Strategy execution result for a single loop iteration.
class StrategyStepResult {
  final bool shouldContinue;
  final dynamic finalOutput;
  final String? thought;
  final List<ToolCall> toolCalls;
  final String? codeSnippet;

  StrategyStepResult({
    required this.shouldContinue,
    this.finalOutput,
    this.thought,
    this.toolCalls = const [],
    this.codeSnippet,
  });

  factory StrategyStepResult.continueLoop({
    String? thought,
    List<ToolCall> toolCalls = const [],
    String? codeSnippet,
  }) =>
      StrategyStepResult(
        shouldContinue: true,
        thought: thought,
        toolCalls: toolCalls,
        codeSnippet: codeSnippet,
      );

  factory StrategyStepResult.finish(dynamic output, {String? thought}) =>
      StrategyStepResult(
        shouldContinue: false,
        finalOutput: output,
        thought: thought,
      );
}

/// Abstract contract for agent execution strategies (inspired by nooa.strategies).
abstract class ExecutionStrategy {
  String get name;
  String get description;

  /// Formats strategy-specific prompt instructions.
  String buildStrategyPrompt(NooaAgent agent);

  /// Processes model response and dictates next step.
  Future<StrategyStepResult> processResponse({
    required NooaAgent agent,
    required ModelResponse modelResponse,
    required List<StepExecution> history,
  });
}
