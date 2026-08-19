import 'dart:convert';
import 'nooa_agent.dart';
import '../models/model_client.dart';

/// Metadata definition of an action exposed by an agent.
class ActionMetadata {
  final String name;
  final String description;
  final List<ToolParameter> parameters;
  final String returnType;
  final bool isDynamic; // If true, executed via dynamic LLM loop (NOOA ellipsis ...)
  final Future<dynamic> Function(Map<String, dynamic> args) invoker;

  ActionMetadata({
    required this.name,
    required this.description,
    this.parameters = const [],
    this.returnType = 'dynamic',
    this.isDynamic = false,
    required this.invoker,
  });

  ToolDefinition toToolDefinition() {
    return ToolDefinition(
      name: name,
      description: description,
      parameters: parameters,
    );
  }
}

/// Reflector synthesizing schemas, docstrings, and prompt contracts from [NooaAgent] classes.
///
/// Implements NOOA Principle 1: "Typed input/output" and prompt synthesis directly from code.
class AgentReflector {
  /// Extracts all actions registered on an agent instance.
  static List<ActionMetadata> getActions(NooaAgent agent) {
    return agent.declaredActions;
  }

  /// Synthesizes the system prompt including agent class docstring, state summary,
  /// live object heap summary, and available methods/actions.
  static String buildSystemPrompt({
    required NooaAgent agent,
    required String heapSummary,
  }) {
    final buffer = StringBuffer();

    // 1. Agent Role & Docstring
    buffer.writeln('# Agent: ${agent.name}');
    if (agent.role.isNotEmpty) {
      buffer.writeln('**Role**: ${agent.role}');
    }
    if (agent.description.isNotEmpty) {
      buffer.writeln('**Description**: ${agent.description}');
    }
    if (agent.customPromptInstructions.isNotEmpty) {
      buffer.writeln('\n## Instructions\n${agent.customPromptInstructions}');
    }

    // 2. Explicit Agent State (NOOA Principle 5)
    buffer.writeln('\n## Current Object State');
    final stateMap = agent.getStateSnapshot();
    if (stateMap.isEmpty) {
      buffer.writeln('State is empty.');
    } else {
      buffer.writeln('```json\n${jsonEncode(stateMap)}\n```');
    }

    // 3. Live Pass-by-Reference Object Heap (NOOA Principle 2)
    buffer.writeln('\n## Live Object Heap (Pass-by-Reference)');
    buffer.writeln(heapSummary);

    // 4. Available Methods / Actions (NOOA Principle 1)
    buffer.writeln('\n## Agent Capabilities & Methods');
    for (final action in agent.declaredActions) {
      final paramsList = action.parameters
          .map((p) => '${p.type} ${p.name}${p.required ? '' : ' (optional)'}')
          .join(', ');
      buffer.writeln('- `${action.name}($paramsList) -> ${action.returnType}`');
      buffer.writeln('  ${action.description}');
    }

    buffer.writeln(
      '\n## Execution Rules\n'
      '1. You can call available methods directly via tool calling or CodeAct.\n'
      '2. Reference live objects in heap using their handle `#ref_xxx` without requesting full raw data.\n'
      '3. Return concise and grounded results.',
    );

    return buffer.toString();
  }
}
