import 'dart:convert';

/// Encapsulates a structured, reusable procedural skill for an autonomous agent.
///
/// Implements ADR 0009: Two-Way Runtime Agent Skills Subsystem (`nooa-skills`).
/// Skills provide deterministic workflows, checklists, and parameter constraints
/// that ensure consistent outcomes across diverse LLM models (from cloud to 1B on-device).
class Skill {
  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final List<String> requiredTools;
  final String instructions;
  final List<Map<String, dynamic>> examples;
  final Map<String, dynamic> metadata;

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    this.tags = const [],
    this.requiredTools = const [],
    required this.instructions,
    this.examples = const [],
    this.metadata = const {},
  });

  /// Checks if this skill is relevant to a given [query] based on text, id, and tags.
  bool matchesQuery(String query) {
    final lower = query.toLowerCase();
    if (id.toLowerCase().contains(lower) || name.toLowerCase().contains(lower) || description.toLowerCase().contains(lower)) {
      return true;
    }
    for (final tag in tags) {
      if (lower.contains(tag.toLowerCase()) || tag.toLowerCase().contains(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Calculates a relevance score between 0.0 and 1.0 against a search [query].
  double matchScore(String query) {
    final tokens = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    if (tokens.isEmpty) return matchesQuery(query) ? 0.5 : 0.0;

    int matches = 0;
    for (final token in tokens) {
      if (id.toLowerCase().contains(token)) matches += 3;
      if (name.toLowerCase().contains(token)) matches += 2;
      if (description.toLowerCase().contains(token)) matches += 1;
      for (final tag in tags) {
        if (tag.toLowerCase() == token) matches += 2;
      }
    }

    final maxPossible = tokens.length * 3;
    return (matches / maxPossible).clamp(0.0, 1.0);
  }

  /// Formats this skill as a clean Markdown prompt block suitable for LLM injection.
  String toPromptMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('### Skill: $name (`$id`)');
    buffer.writeln('**Description**: $description');
    if (requiredTools.isNotEmpty) {
      buffer.writeln('**Required Tools**: `${requiredTools.join("`, `")}`');
    }
    buffer.writeln('\n**Execution Recipe & Guidelines**:');
    buffer.writeln(instructions.trim());
    if (examples.isNotEmpty) {
      buffer.writeln('\n**Examples**:');
      for (final ex in examples) {
        buffer.writeln('```json');
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(ex));
        buffer.writeln('```');
      }
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tags': tags,
        'requiredTools': requiredTools,
        'instructions': instructions,
        'examples': examples,
        'metadata': metadata,
      };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as String? ?? 'unknown-skill',
        name: json['name'] as String? ?? 'Unnamed Skill',
        description: json['description'] as String? ?? '',
        tags: List<String>.from(json['tags'] as List? ?? []),
        requiredTools: List<String>.from(json['requiredTools'] as List? ?? []),
        instructions: json['instructions'] as String? ?? '',
        examples: (json['examples'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      );

  @override
  String toString() => 'Skill($id: $name)';
}
