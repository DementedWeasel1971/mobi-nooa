import 'dart:async';
import 'dart:convert';

/// Represents the role of a message in a conversation.
enum MessageRole {
  system,
  user,
  assistant,
  tool,
}

/// A structured message in an agent-model conversation.
class ModelMessage {
  final MessageRole role;
  final String content;
  final String? name;
  final String? toolCallId;
  final List<ToolCall>? toolCalls;
  final Map<String, dynamic>? metadata;

  ModelMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
    this.metadata,
  });

  factory ModelMessage.system(String content) =>
      ModelMessage(role: MessageRole.system, content: content);

  factory ModelMessage.user(String content) =>
      ModelMessage(role: MessageRole.user, content: content);

  factory ModelMessage.assistant(String content, {List<ToolCall>? toolCalls}) =>
      ModelMessage(
        role: MessageRole.assistant,
        content: content,
        toolCalls: toolCalls,
      );

  factory ModelMessage.tool({
    required String content,
    required String toolCallId,
    String? name,
  }) =>
      ModelMessage(
        role: MessageRole.tool,
        content: content,
        toolCallId: toolCallId,
        name: name,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        if (name != null) 'name': name,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((tc) => tc.toJson()).toList(),
      };
}

/// Parameter definition for an action / tool schema.
class ToolParameter {
  final String name;
  final String type;
  final String description;
  final bool required;
  final List<dynamic>? enumValues;
  final dynamic defaultValue;

  const ToolParameter({
    required this.name,
    required this.type,
    required this.description,
    this.required = true,
    this.enumValues,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        if (enumValues != null) 'enum': enumValues,
      };
}

/// Tool / Action definition provided to the LLM.
class ToolDefinition {
  final String name;
  final String description;
  final List<ToolParameter> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': {
            'type': 'object',
            'properties': {
              for (final p in parameters) p.name: p.toJson(),
            },
            'required':
                parameters.where((p) => p.required).map((p) => p.name).toList(),
          },
        },
      };
}

/// Tool call invocation emitted by the model.
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': jsonEncode(arguments),
        },
      };

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final func = json['function'] as Map<String, dynamic>? ?? {};
    final rawArgs = func['arguments'];
    Map<String, dynamic> parsedArgs = {};
    if (rawArgs is String && rawArgs.isNotEmpty) {
      try {
        parsedArgs = jsonDecode(rawArgs) as Map<String, dynamic>;
      } catch (_) {
        parsedArgs = {'_raw': rawArgs};
      }
    } else if (rawArgs is Map<String, dynamic>) {
      parsedArgs = rawArgs;
    }

    return ToolCall(
      id: (json['id'] as String?) ?? 'call_${DateTime.now().microsecondsSinceEpoch}',
      name: (func['name'] as String?) ?? (json['name'] as String? ?? 'unknown'),
      arguments: parsedArgs,
    );
  }
}

/// Token usage details including prompt cache statistics.
class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int? promptCacheHitTokens;
  final int? promptCacheMissTokens;

  const TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.promptCacheHitTokens,
    this.promptCacheMissTokens,
  });
}

/// Response returned by a [ModelClient].
class ModelResponse {
  final String text;
  final String? reasoningContent;
  final List<ToolCall> toolCalls;
  final String finishReason;
  final TokenUsage usage;
  final Map<String, dynamic> rawResponse;

  ModelResponse({
    this.text = '',
    this.reasoningContent,
    this.toolCalls = const [],
    this.finishReason = 'stop',
    this.usage = const TokenUsage(),
    this.rawResponse = const {},
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
  bool get hasReasoning => reasoningContent != null && reasoningContent!.isNotEmpty;
}

/// Abstract contract for any model provider (Cloud or On-Device).
abstract class ModelClient {
  String get modelName;

  /// Generates a response given conversation history and available tools.
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  });
}
