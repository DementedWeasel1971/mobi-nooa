/// Types of chronological events stored in the append-only session log.
enum SessionEventType {
  userMessage,
  assistantThought,
  assistantResponse,
  toolCall,
  toolResult,
  codeActSnippet,
  codeActResult,
  stateChange,
  checkpoint,
  error,
}

/// A discrete, immutable record of an event in an agent session.
class SessionEvent {
  final String id;
  final String sessionId;
  final int stepIndex;
  final SessionEventType type;
  final Map<String, dynamic> data;
  final String summary;
  final DateTime timestamp;

  SessionEvent({
    String? id,
    required this.sessionId,
    required this.stepIndex,
    required this.type,
    required this.data,
    this.summary = '',
    DateTime? timestamp,
  })  : id = id ?? 'evt_${DateTime.now().microsecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'stepIndex': stepIndex,
        'type': type.name,
        'data': data,
        'summary': summary,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      id: json['id'] as String?,
      sessionId: (json['sessionId'] as String?) ?? '',
      stepIndex: (json['stepIndex'] as int?) ?? 0,
      type: SessionEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SessionEventType.userMessage,
      ),
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      summary: (json['summary'] as String?) ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
