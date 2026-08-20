import 'dart:async';
import 'skill_store.dart';
import '../security/ast_guardrails.dart';

/// Enhances agent prompts by dynamically matching and injecting relevant procedural skills
/// with automatic prompt injection and control token sanitization.
///
/// Implements INBOUND skill injection ("to the agent") to guide model reasoning.
class SkillPromptEnhancer {
  final SkillStore store;

  SkillPromptEnhancer(this.store);

  /// Matches skills relevant to [goal] and formats them into a Markdown prompt section.
  Future<String?> buildSkillsPromptSection(String goal, {int maxSkills = 2}) async {
    final matched = await store.findSkills(goal, limit: maxSkills);
    if (matched.isEmpty) return null;

    final buffer = StringBuffer();
    buffer.writeln('## Relevant Skills & Procedural Recipes');
    buffer.writeln('Follow the guidelines below to execute this task reliably:\n');

    for (final skill in matched) {
      final sanitizedMarkdown = AstGuardrails.sanitizePromptText(skill.toPromptMarkdown());
      buffer.writeln(sanitizedMarkdown);
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Appends relevant skill recipes directly to an existing system prompt string.
  Future<String> enhancePrompt(String basePrompt, String goal, {int maxSkills = 2}) async {
    final section = await buildSkillsPromptSection(goal, maxSkills: maxSkills);
    if (section == null || section.isEmpty) return basePrompt;

    return '$basePrompt\n\n$section';
  }
}
