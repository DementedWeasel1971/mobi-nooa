import 'dart:async';
import 'dart:convert';
import 'trace_event.dart';
import '../models/model_client.dart';

/// Active tracer collecting events, spans, and telemetry for NOOA agents.
class Tracer {
  final String agentName;
  final List<TraceEvent> _events = [];
  final StreamController<TraceEvent> _eventStreamController =
      StreamController<TraceEvent>.broadcast();
  int _eventCounter = 0;

  TokenUsage _cumulativeUsage = const TokenUsage();

  Tracer(this.agentName);

  /// Live stream of execution events (useful for Flutter UI, live terminal, or WebSocket streams).
  Stream<TraceEvent> get onEvent => _eventStreamController.stream;

  /// Full history of recorded events.
  List<TraceEvent> get events => List.unmodifiable(_events);

  /// Cumulative token usage across all steps and subagents.
  TokenUsage get cumulativeUsage => _cumulativeUsage;

  /// Records a trace event.
  TraceEvent record({
    required TraceEventType type,
    required String description,
    int stepIndex = 0,
    Map<String, dynamic> data = const {},
    TokenUsage? tokenUsage,
    Duration? duration,
  }) {
    if (tokenUsage != null) {
      _cumulativeUsage = TokenUsage(
        promptTokens: _cumulativeUsage.promptTokens + tokenUsage.promptTokens,
        completionTokens:
            _cumulativeUsage.completionTokens + tokenUsage.completionTokens,
        totalTokens: _cumulativeUsage.totalTokens + tokenUsage.totalTokens,
      );
    }

    final event = TraceEvent(
      id: 'evt_${++_eventCounter}',
      agentName: agentName,
      type: type,
      timestamp: DateTime.now(),
      stepIndex: stepIndex,
      description: description,
      data: data,
      tokenUsage: tokenUsage,
      duration: duration,
    );

    _events.add(event);
    _eventStreamController.add(event);
    return event;
  }

  /// Creates a child tracer for a spawned subagent.
  Tracer createChildTracer(String subagentName) {
    final child = Tracer('$agentName/$subagentName');
    child.onEvent.listen((event) {
      _events.add(event);
      _eventStreamController.add(event);
    });
    return child;
  }

  /// Exports the full trace log in JSON Lines (.jsonl) format.
  String exportJsonL() {
    return _events.map((e) => jsonEncode(e.toJson())).join('\n');
  }

  void dispose() {
    _eventStreamController.close();
  }
}
