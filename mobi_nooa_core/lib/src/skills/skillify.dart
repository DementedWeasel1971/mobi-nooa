import 'dart:async';
import '../session/session_event.dart';
import '../session/session_event_log.dart';
import 'skill.dart';
import 'skill_store.dart';

/// Trajectory-to-Skill Synthesizer (`/skillify`).
///
/// Implements Grok Build's `/skillify` concept:
/// Analyzes a successful multi-step agent trajectory and automatically distills it
/// into a permanent, reusable procedural [Skill] recipe.
class SkillifySynthesizer {
  /// Synthesizes a structured [Skill] from a recorded [SessionEventLog].
  static Skill distillSession({
    required SessionEventLog sessionLog,
    String? customSkillName,
    String? category,
  }) {
    final events = sessionLog.events;
    if (events.isEmpty) {
      final name = customSkillName ?? 'synthesized_${sessionLog.sessionId}';
      return Skill(
        id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_'),
        name: name,
        description: 'Synthesized procedure from session ${sessionLog.sessionId}',
        instructions: 'Execute steps recorded during session ${sessionLog.sessionId}',
        tags: [name, 'session'],
        requiredTools: const [],
      );
    }

    // 1. Extract Initial Goal
    String initialGoal = 'Autonomous Task';
    final userEvents = events.where((e) => e.type == SessionEventType.userMessage);
    if (userEvents.isNotEmpty) {
      initialGoal = userEvents.first.data['prompt'] as String? ??
          userEvents.first.data['goal'] as String? ??
          userEvents.first.summary;
      if (initialGoal.isEmpty) initialGoal = 'Autonomous Task';
    }

    // 2. Extract Tool Calls and Sequence
    final toolCallEvents = events.where((e) => e.type == SessionEventType.toolCall);
    final recipeSteps = <String>[];
    final toolNames = <String>{};

    int stepNum = 1;
    for (final ev in toolCallEvents) {
      final toolName = ev.data['toolName'] as String? ?? 'tool';
      toolNames.add(toolName);
      final args = ev.data['arguments'];
      recipeSteps.add('Step $stepNum: Execute `$toolName` with parameters `$args`.');
      stepNum++;
    }

    if (recipeSteps.isEmpty) {
      recipeSteps.add('Execute autonomous ReAct loop to satisfy objective: "$initialGoal".');
    }

    // 3. Formulate Trigger Tags / Queries
    final queryWords = initialGoal
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    final skillId = (customSkillName ?? 'skill_${sessionLog.sessionId}')
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w-]'), '_');

    final skillName = customSkillName ?? 'Workflow: $initialGoal';

    return Skill(
      id: skillId,
      name: skillName,
      description: 'Synthesized procedural workflow for: "$initialGoal". Tools used: [${toolNames.join(", ")}].',
      tags: queryWords.isNotEmpty ? queryWords : [skillId],
      requiredTools: toolNames.toList(),
      instructions: recipeSteps.join('\n'),
      metadata: {
        'synthesizedFromSession': sessionLog.sessionId,
        'toolsUsed': toolNames.toList(),
        'totalSteps': recipeSteps.length,
        'category': category ?? 'synthesized_workflow',
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Distills a session and automatically saves it to the target [SkillStore].
  static Future<Skill> skillifyAndSave({
    required SessionEventLog sessionLog,
    required SkillStore skillStore,
    String? customSkillName,
  }) async {
    final skill = distillSession(
      sessionLog: sessionLog,
      customSkillName: customSkillName,
    );
    await skillStore.saveSkill(skill);
    return skill;
  }
}
