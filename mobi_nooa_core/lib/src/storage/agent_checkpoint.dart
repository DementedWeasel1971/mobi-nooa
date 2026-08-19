import 'dart:convert';
import '../heap/object_reference.dart';

/// Comprehensive snapshot of an agent's execution state for persistence and pause/resume.
class AgentCheckpoint {
  final String checkpointId;
  final String agentName;
  final DateTime timestamp;
  final int stepIndex;
  final Map<String, dynamic> stateSnapshot;
  final List<ObjectReference> heapReferences;
  final Map<String, dynamic> environment;
  final String status; // 'running', 'paused', 'completed', 'error'

  AgentCheckpoint({
    required this.checkpointId,
    required this.agentName,
    DateTime? timestamp,
    this.stepIndex = 0,
    required this.stateSnapshot,
    this.heapReferences = const [],
    this.environment = const {},
    this.status = 'running',
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'checkpointId': checkpointId,
        'agentName': agentName,
        'timestamp': timestamp.toIso8601String(),
        'stepIndex': stepIndex,
        'stateSnapshot': stateSnapshot,
        'heapReferences': heapReferences.map((r) => r.toJson()).toList(),
        'environment': environment,
        'status': status,
      };

  factory AgentCheckpoint.fromJson(Map<String, dynamic> json) =>
      AgentCheckpoint(
        checkpointId: json['checkpointId'] as String,
        agentName: json['agentName'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        stepIndex: (json['stepIndex'] as int?) ?? 0,
        stateSnapshot: (json['stateSnapshot'] as Map<String, dynamic>?) ?? {},
        heapReferences: ((json['heapReferences'] as List?) ?? [])
            .map((r) => ObjectReference.fromJson(r as Map<String, dynamic>))
            .toList(),
        environment: (json['environment'] as Map<String, dynamic>?) ?? {},
        status: (json['status'] as String?) ?? 'running',
      );

  String toJsonString() => jsonEncode(toJson());

  factory AgentCheckpoint.fromJsonString(String str) =>
      AgentCheckpoint.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
