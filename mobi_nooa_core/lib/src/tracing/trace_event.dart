import '../models/model_client.dart';

/// Types of trace events recorded during NOOA agent execution.
enum TraceEventType {
  agentStart,
  stepStart,
  llmPrompt,
  llmResponse,
  providerError,
  providerFallback,
  providerRecovered,
  codeActExecution,
  toolExecution,
  objectHeapMutation,
  stateMutation,
  subagentSpawn,
  stepEnd,
  agentFinish,
  error,
}

/// Structured trace event for real-time observability, debugging, and benchmarking.
class TraceEvent {
  final String id;
  final String agentName;
  final TraceEventType type;
  final DateTime timestamp;
  final int stepIndex;
  final String description;
  final Map<String, dynamic> data;
  final TokenUsage? tokenUsage;
  final Duration? duration;

  TraceEvent({
    required this.id,
    required this.agentName,
    required this.type,
    required this.timestamp,
    this.stepIndex = 0,
    required this.description,
    this.data = const {},
    this.tokenUsage,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentName': agentName,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'stepIndex': stepIndex,
        'description': description,
        'data': data,
        if (tokenUsage != null)
          'tokenUsage': {
            'promptTokens': tokenUsage!.promptTokens,
            'completionTokens': tokenUsage!.completionTokens,
            'totalTokens': tokenUsage!.totalTokens,
          },
        if (duration != null) 'durationMs': duration!.inMilliseconds,
      };

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] [$agentName] ${type.name} (step $stepIndex): $description';
}
