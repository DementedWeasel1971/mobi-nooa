import 'dart:async';
import 'agent_checkpoint.dart';
import '../harness/sqlite_harness.dart';

/// Storage manager for persisting agent checkpoints, traces, and state snapshots.
///
/// Implements NOOA's `nooa.storage` SQLite persistence architecture.
class StateStorageManager {
  final SqliteHarness sqlite;

  StateStorageManager({required this.sqlite});

  /// Initializes the storage table schemas.
  Future<void> initialize() async {
    await sqlite.execute('''
      CREATE TABLE IF NOT EXISTS agent_checkpoints (
        checkpoint_id TEXT PRIMARY KEY,
        agent_name TEXT,
        timestamp TEXT,
        step_index INTEGER,
        status TEXT,
        data TEXT
      )
    ''');
  }

  /// Saves an agent checkpoint.
  Future<void> saveCheckpoint(AgentCheckpoint checkpoint) async {
    await sqlite.execute(
      '''
      INSERT INTO agent_checkpoints (checkpoint_id, agent_name, timestamp, step_index, status, data)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        checkpoint.checkpointId,
        checkpoint.agentName,
        checkpoint.timestamp.toIso8601String(),
        checkpoint.stepIndex,
        checkpoint.status,
        checkpoint.toJsonString(),
      ],
    );
  }

  /// Retrieves the latest checkpoint for an agent.
  Future<AgentCheckpoint?> getLatestCheckpoint(String agentName) async {
    final result = await sqlite.query(
      'SELECT data FROM agent_checkpoints WHERE agent_name = ? ORDER BY timestamp DESC LIMIT 1',
      [agentName],
    );

    if (result.rows.isEmpty) return null;
    final row = result.toListOfMaps().first;
    final jsonStr = row['data'] as String?;
    if (jsonStr == null) return null;

    return AgentCheckpoint.fromJsonString(jsonStr);
  }

  /// Lists all stored checkpoints for an agent.
  Future<List<AgentCheckpoint>> listCheckpoints(String agentName) async {
    final result = await sqlite.query(
      'SELECT data FROM agent_checkpoints WHERE agent_name = ? ORDER BY timestamp ASC',
      [agentName],
    );

    return result
        .toListOfMaps()
        .map((r) => r['data'] as String?)
        .whereType<String>()
        .map((s) => AgentCheckpoint.fromJsonString(s))
        .toList();
  }
}
