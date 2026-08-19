import '../models/model_client.dart';

/// Represents the execution of a single step within an agentic loop.
class StepExecution {
  final int stepIndex;
  final String thought;
  final List<ToolCall> toolCalls;
  final List<String> toolOutputs;
  final String? codeSnippet;
  final String? codeOutput;
  final TokenUsage? tokenUsage;
  final Duration duration;
  final bool isTerminal;

  StepExecution({
    required this.stepIndex,
    this.thought = '',
    this.toolCalls = const [],
    this.toolOutputs = const [],
    this.codeSnippet,
    this.codeOutput,
    this.tokenUsage,
    required this.duration,
    this.isTerminal = false,
  });
}
