import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 09: SQLite State Checkpointing and Crash Recovery (nooa.storage)
///
/// Demonstrates saving agent state, loop counters, and heap handles into SQLite
/// so tasks survive application restarts and background process kills.
Future<void> main() async {
  print('=== mobi-nooa Tutorial 09: Checkpoint Storage & Resume ===\n');

  final sqlite = InMemorySqliteHarness();
  final storageManager = StateStorageManager(sqlite: sqlite);
  await storageManager.initialize();

  // 1. Simulate agent making progress and pausing
  final checkpoint = AgentCheckpoint(
    checkpointId: 'session_chk_4001',
    agentName: 'WorkflowAgent',
    stepIndex: 5,
    stateSnapshot: {
      'currentStep': 'parsing_json_logs',
      'recordsProcessed': 1420,
      'isComplete': false,
    },
    heapReferences: [
      ObjectReference(
        handle: '#ref_1',
        typeName: 'List<Map<String, dynamic>>',
        preview: '[1420 parsed log entries]',
      ),
    ],
    status: 'paused',
  );

  print('Saving checkpoint session_chk_4001 to SQLite storage...');
  await storageManager.saveCheckpoint(checkpoint);

  // 2. Simulate resuming agent after app restart
  print('Resuming latest checkpoint for WorkflowAgent...');
  final resumed = await storageManager.getLatestCheckpoint('WorkflowAgent');

  if (resumed != null) {
    print('\nSuccessfully Resumed Agent State:');
    print('- Checkpoint ID: ${resumed.checkpointId}');
    print('- Resumed Step: ${resumed.stepIndex}');
    print('- Stored Records: ${resumed.stateSnapshot['recordsProcessed']}');
    print('- Stored Heap Handles: ${resumed.heapReferences.map((r) => r.handle).toList()}');
    print('- Agent Status: ${resumed.status}');
  }
}
