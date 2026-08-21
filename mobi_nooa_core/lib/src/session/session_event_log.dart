import 'dart:convert';
import 'session_event.dart';

/// Reconstructed agent state and history at a particular point in time.
class ReplayState {
  final int stepIndex;
  final Map<String, dynamic> state;
  final List<SessionEvent> eventHistory;

  const ReplayState({
    required this.stepIndex,
    required this.state,
    required this.eventHistory,
  });
}

/// Append-only event log capturing the complete, auditable trace of an agent session.
///
/// Implements DeepSeek Harness append-only event logging, time-travel replay,
/// and session branching / forking.
class SessionEventLog {
  final String sessionId;
  final List<SessionEvent> _events = [];

  SessionEventLog({required this.sessionId});

  /// Read-only list of all recorded events in chronological order.
  List<SessionEvent> get events => List.unmodifiable(_events);

  /// Appends an event to the log.
  void append(SessionEvent event) {
    _events.add(event);
  }

  /// Filters events by [type].
  List<SessionEvent> filterByType(SessionEventType type) {
    return _events.where((e) => e.type == type).toList();
  }

  /// Returns all events up to and including [stepIndex].
  List<SessionEvent> getEventsUpToStep(int stepIndex) {
    return _events.where((e) => e.stepIndex <= stepIndex).toList();
  }

  /// Replays events up to [toStepIndex] to reconstruct the agent state snapshot.
  ReplayState replay(int toStepIndex) {
    final relevantEvents = getEventsUpToStep(toStepIndex);
    final reconstructedState = <String, dynamic>{};

    for (final event in relevantEvents) {
      if (event.type == SessionEventType.stateChange) {
        final key = event.data['key'] as String?;
        if (key != null) {
          reconstructedState[key] = event.data['value'];
        }
      } else if (event.type == SessionEventType.checkpoint) {
        final snapshot = event.data['snapshot'] as Map<String, dynamic>?;
        if (snapshot != null) {
          reconstructedState.clear();
          reconstructedState.addAll(snapshot);
        }
      }
    }

    return ReplayState(
      stepIndex: toStepIndex,
      state: reconstructedState,
      eventHistory: relevantEvents,
    );
  }

  /// Creates a branched/forked independent session log starting from [fromStepIndex].
  SessionEventLog fork({
    required String newSessionId,
    int? fromStepIndex,
  }) {
    final forked = SessionEventLog(sessionId: newSessionId);
    final sourceEvents = fromStepIndex != null
        ? getEventsUpToStep(fromStepIndex)
        : _events;

    for (final e in sourceEvents) {
      forked.append(
        SessionEvent(
          sessionId: newSessionId,
          stepIndex: e.stepIndex,
          type: e.type,
          data: Map<String, dynamic>.from(e.data),
          summary: e.summary,
          timestamp: e.timestamp,
        ),
      );
    }
    return forked;
  }

  /// Serializes the entire session log to a JSON map.
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'events': _events.map((e) => e.toJson()).toList(),
      };

  /// Restores a [SessionEventLog] from a JSON map.
  factory SessionEventLog.fromJson(Map<String, dynamic> json) {
    final sessionId = (json['sessionId'] as String?) ?? '';
    final log = SessionEventLog(sessionId: sessionId);
    final rawEvents = json['events'] as List? ?? [];
    for (final re in rawEvents) {
      if (re is Map<String, dynamic>) {
        log.append(SessionEvent.fromJson(re));
      }
    }
    return log;
  }

  /// Serializes the session log into newline-delimited JSON (JSONL).
  String toJsonLines() {
    final buffer = StringBuffer();
    for (final event in _events) {
      buffer.writeln(jsonEncode(event.toJson()));
    }
    return buffer.toString();
  }

  /// Deserializes a [SessionEventLog] from newline-delimited JSON (JSONL).
  factory SessionEventLog.fromJsonLines(String sessionId, String jsonLines) {
    final log = SessionEventLog(sessionId: sessionId);
    for (final line in jsonLines.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final parsed = jsonDecode(trimmed) as Map<String, dynamic>;
        log.append(SessionEvent.fromJson(parsed));
      } catch (_) {}
    }
    return log;
  }
}
