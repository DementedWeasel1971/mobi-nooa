import 'dart:async';
import 'dart:convert';
import 'skill.dart';
import '../harness/filesystem_harness.dart';

/// Contract for cataloging, searching, and persisting procedural agent skills.
abstract class SkillStore {
  /// Returns all skills currently available in this store.
  Future<List<Skill>> listSkills();

  /// Searches for skills matching [query], sorted by relevance score descending.
  Future<List<Skill>> findSkills(String query, {int limit = 3});

  /// Retrieves a specific skill by its unique [id].
  Future<Skill?> getSkill(String id);

  /// Persists or updates a [skill] in this store.
  Future<void> saveSkill(Skill skill);

  /// Deletes a skill by [id]. Returns true if found and removed.
  Future<bool> deleteSkill(String id);
}

/// In-memory skill catalog pre-seeded with standard mobile and software engineering skills.
class InMemorySkillStore implements SkillStore {
  final Map<String, Skill> _skills = {};

  InMemorySkillStore({List<Skill>? seedSkills}) {
    final defaultSeeds = seedSkills ?? defaultCatalog;
    for (final skill in defaultSeeds) {
      _skills[skill.id] = skill;
    }
  }

  @override
  Future<List<Skill>> listSkills() async => _skills.values.toList();

  @override
  Future<List<Skill>> findSkills(String query, {int limit = 3}) async {
    final scored = _skills.values
        .map((s) => MapEntry(s, s.matchScore(query)))
        .where((e) => e.value > 0.0)
        .toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  @override
  Future<Skill?> getSkill(String id) async => _skills[id];

  @override
  Future<void> saveSkill(Skill skill) async {
    _skills[skill.id] = skill;
  }

  @override
  Future<bool> deleteSkill(String id) async {
    return _skills.remove(id) != null;
  }

  /// Default seed catalog of essential mobile and coding agent skills.
  static final List<Skill> defaultCatalog = [
    const Skill(
      id: 'mobile-battery-diagnostics',
      name: 'Mobile Battery & Telemetry Diagnostics',
      description: 'Systematic workflow for diagnosing mobile power status and alerting the user upon critical drain.',
      tags: ['battery', 'device', 'telemetry', 'mobile', 'status', 'power'],
      requiredTools: ['getDeviceInfo', 'sendNotification'],
      instructions: '''
1. Invoke `getDeviceInfo()` to capture battery level, charging status, and network state.
2. Check if `batteryLevel < 0.20` and `isCharging == false`.
3. If low battery condition is met, emit a notification using `sendNotification` with urgency details.
4. Record the telemetry snapshot in agent state for tracking.
''',
      examples: [
        {
          'goal': 'Check if phone battery is low and alert me',
          'step_1': 'getDeviceInfo() -> {"batteryLevel": 0.15, "isCharging": false}',
          'step_2': 'sendNotification(title: "Low Battery Warning", body: "Battery at 15%. Connect charger.")'
        }
      ],
    ),
    const Skill(
      id: 'exact-str-replace-editing',
      name: 'Exact Substring Replace Editing',
      description: 'Robust source file editing pattern using unique whitespace-exact string replacement.',
      tags: ['edit', 'file', 'strReplace', 'coding', 'source', 'patch'],
      requiredTools: ['viewFile', 'strReplace'],
      instructions: '''
1. Always call `viewFile(path, startLine, endLine)` first to inspect the target code lines with exact indentation.
2. Select an `oldStr` that contains enough surrounding context (3-5 lines) to be completely unique in the target file.
3. Verify that `newStr` preserves the original file's whitespace and indentation conventions.
4. Call `strReplace(path, oldStr, newStr)` and verify the edit succeeded with 1 replacement.
''',
    ),
    const Skill(
      id: 'sqlite-checkpoint-recovery',
      name: 'SQLite State Checkpoint & Recovery',
      description: 'Pattern for safely saving and resuming agent state checkpoints to SQLite.',
      tags: ['sqlite', 'storage', 'checkpoint', 'persistence', 'recovery'],
      requiredTools: ['saveCheckpoint', 'getLatestCheckpoint'],
      instructions: '''
1. Periodically capture a snapshot of explicit agent state via `getStateSnapshot()`.
2. Construct an `AgentCheckpoint` record with step index and heap handles.
3. Commit the checkpoint using `StateStorageManager.saveCheckpoint()`.
4. Upon process resume, verify checkpoint integrity and restore heap references.
''',
    ),
  ];
}

/// Filesystem-backed skill store persisting skills as JSON files in a dedicated directory.
class FileSystemSkillStore implements SkillStore {
  final FileSystemHarness _fs;
  final String _skillsDirectory;
  bool _initialized = false;

  FileSystemSkillStore(this._fs, {String skillsDirectory = '/skills'})
      : _skillsDirectory = skillsDirectory;

  Future<void> _ensureDir() async {
    if (_initialized) return;
    _initialized = true;
    if (!await _fs.exists(_skillsDirectory)) {
      // Seed default skills into filesystem
      for (final seed in InMemorySkillStore.defaultCatalog) {
        final path = '$_skillsDirectory/${seed.id}.json';
        final content = const JsonEncoder.withIndent('  ').convert(seed.toJson());
        await _fs.writeFile(path, content);
      }
    }
  }

  @override
  Future<List<Skill>> listSkills() async {
    await _ensureDir();
    final files = await _fs.listFiles(_skillsDirectory);
    final skills = <Skill>[];

    for (final file in files) {
      if (file.endsWith('.json')) {
        try {
          final content = await _fs.readFile(file);
          final json = jsonDecode(content) as Map<String, dynamic>;
          skills.add(Skill.fromJson(json));
        } catch (_) {}
      }
    }
    return skills;
  }

  @override
  Future<List<Skill>> findSkills(String query, {int limit = 3}) async {
    final all = await listSkills();
    final scored = all
        .map((s) => MapEntry(s, s.matchScore(query)))
        .where((e) => e.value > 0.0)
        .toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  @override
  Future<Skill?> getSkill(String id) async {
    await _ensureDir();
    final path = '$_skillsDirectory/$id.json';
    if (!await _fs.exists(path)) return null;
    try {
      final content = await _fs.readFile(path);
      return Skill.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSkill(Skill skill) async {
    await _ensureDir();
    final path = '$_skillsDirectory/${skill.id}.json';
    final content = const JsonEncoder.withIndent('  ').convert(skill.toJson());
    await _fs.writeFile(path, content);
  }

  @override
  Future<bool> deleteSkill(String id) async {
    await _ensureDir();
    final path = '$_skillsDirectory/$id.json';
    if (await _fs.exists(path)) {
      await _fs.deleteFile(path);
      return true;
    }
    return false;
  }
}
