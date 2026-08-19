# ADR 0004: SQLite-backed checkpoint persistence

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

Mobile agents must survive process death (app backgrounding, OS memory
pressure) without losing progress on a long-running task. This requires
serializing an agent's explicit state, step index, and heap references at
well-defined points, and reloading them to resume.

## Decision

Introduce `lib/src/storage/`:

- `AgentCheckpoint` — a JSON-serializable snapshot (`checkpointId`,
  `agentName`, `timestamp`, `stepIndex`, `stateSnapshot`, `heapReferences`,
  `environment`, `status`) with `toJsonString`/`fromJsonString`.
- `StateStorageManager` — persists/retrieves checkpoints through the
  `SqliteHarness` interface (`lib/src/harness/sqlite_harness.dart`),
  creating an `agent_checkpoints` table and exposing `saveCheckpoint`,
  `getLatestCheckpoint`, `listCheckpoints`.

`StateStorageManager` depends only on the abstract `SqliteHarness`, not a
concrete database, keeping `mobi_nooa_core` free of a hard SQLite
dependency.

## Alternatives considered

- **Flat-file JSON checkpoints via `FileSystemHarness`** — rejected for the
  primary path: SQLite gives indexed lookup-by-agent and ordered history
  (`listCheckpoints`) without hand-rolled file-naming schemes; still
  possible as an alternate `SqliteHarness`-free path later if needed.
- **In-memory-only checkpoints** — rejected: does not survive process
  death, defeating the purpose.

## Consequences

- All new persistence code should go through `AgentCheckpoint` +
  `StateStorageManager`, not ad-hoc serialization (see `AGENTS.md`).
- **Known gap**: the only `SqliteHarness` implementation today is
  `InMemorySqliteHarness` (`lib/src/harness/sqlite_harness.dart`), which
  does not actually persist across process restarts. A real SQLite binding
  (e.g. an FFI-based `sqlite3` package, or a native bridge from
  `android_mobi_nooa`) must replace it before checkpoint/resume works in
  production — tracked in `DESIGN.md`'s open architecture questions.
