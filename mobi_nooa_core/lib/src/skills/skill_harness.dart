import 'skill.dart';
import 'skill_store.dart';

/// Model-callable harness for dynamic skill discovery, loading, and authoring.
///
/// Implements NOOA Principle 6 ("Model-callable harness APIs") for procedural knowledge.
class SkillHarness {
  final SkillStore store;

  SkillHarness([SkillStore? store]) : store = store ?? InMemorySkillStore();

  /// Searches for skills matching [query] and returns lightweight summaries.
  Future<List<Map<String, dynamic>>> searchSkills(String query, {int limit = 5}) async {
    final skills = await store.findSkills(query, limit: limit);
    return skills.map((s) => {
          'id': s.id,
          'name': s.name,
          'description': s.description,
          'tags': s.tags,
          'requiredTools': s.requiredTools,
        }).toList();
  }

  /// Loads full step-by-step instructions and examples for a skill by [id].
  Future<Map<String, dynamic>?> loadSkill(String id) async {
    final skill = await store.getSkill(id);
    return skill?.toJson();
  }

  /// Synthesizes and persists a newly learned skill into the store.
  ///
  /// This enables OUTBOUND skill learning ("from the agent").
  Future<Map<String, dynamic>> createSkill({
    required String id,
    required String name,
    required String description,
    required String instructions,
    List<String> tags = const [],
    List<String> requiredTools = const [],
    List<Map<String, dynamic>> examples = const [],
  }) async {
    final skill = Skill(
      id: id,
      name: name,
      description: description,
      instructions: instructions,
      tags: tags,
      requiredTools: requiredTools,
      examples: examples,
    );

    await store.saveSkill(skill);

    return {
      'status': 'created',
      'skillId': skill.id,
      'name': skill.name,
    };
  }

  /// Lists all available skill summaries.
  Future<List<Map<String, dynamic>>> listSkills() async {
    final all = await store.listSkills();
    return all.map((s) => {
          'id': s.id,
          'name': s.name,
          'description': s.description,
          'tags': s.tags,
        }).toList();
  }
}
