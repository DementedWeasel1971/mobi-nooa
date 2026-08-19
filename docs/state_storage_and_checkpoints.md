# State Storage & Checkpoint Persistence (`nooa.storage`)

Mobile applications can be paused, minimized, or terminated by Android's Low Memory Killer (LMK) at any time. To guarantee long-running agent workflows are reliable, **`mobi-nooa`** implements the **`nooa.storage`** SQLite state persistence architecture.

---

## 💾 1. `AgentCheckpoint` Model

An `AgentCheckpoint` captures the complete serialized snapshot of an agent's execution:

```json
{
  "checkpointId": "chk_session_9012",
  "agentName": "BenchAgent",
  "timestamp": "2026-08-19T21:40:00.000Z",
  "stepIndex": 4,
  "stateSnapshot": {
    "targetFile": "/workspace/chunker.py",
    "bugFixed": true
  },
  "heapReferences": [
    {
      "handle": "#ref_1",
      "typeName": "List<String>",
      "preview": "[line 1, line 2, line 3]"
    }
  ],
  "environment": {
    "cwd": "/workspace"
  },
  "status": "paused"
}
```

---

## 🗄️ 2. `StateStorageManager` (SQLite)

`StateStorageManager` manages the `agent_checkpoints` relational table in SQLite:

```dart
final sqlite = InMemorySqliteHarness(); // Or native Android SQLite
final storage = StateStorageManager(sqlite: sqlite);
await storage.initialize();

// Save checkpoint
await storage.saveCheckpoint(checkpoint);

// Resume latest checkpoint across app reboots
final resumedCheckpoint = await storage.getLatestCheckpoint('BenchAgent');
```

---

## 🔄 3. Restoring Agent State

To restore an agent from a stored checkpoint:

```dart
final agent = Quickstart.createAgent(() => BenchAgent());

final checkpoint = await storage.getLatestCheckpoint(agent.name);
if (checkpoint != null) {
  // Restore explicit state map
  agent.restoreState(checkpoint.stateSnapshot);

  print('Restored agent state to step ${checkpoint.stepIndex}');
}
```
