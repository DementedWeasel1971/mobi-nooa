import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// Anthropic Claude LLM adapter.
class AnthropicClient implements ModelClient {
  final String apiKey;
  @override
  final String modelName;
  final String baseUrl;
  final String apiVersion;
  final http.Client _httpClient;

  AnthropicClient({
    required this.apiKey,
    this.modelName = 'claude-3-5-sonnet-20241022',
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.apiVersion = '2023-06-01',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    final url = Uri.parse('$baseUrl/messages');

    String? systemPrompt;
    final convertedMessages = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == MessageRole.system) {
        systemPrompt = msg.content;
      } else if (msg.role == MessageRole.user) {
        convertedMessages.add({'role': 'user', 'content': msg.content});
      } else if (msg.role == MessageRole.assistant) {
        final contentList = <Map<String, dynamic>>[];
        if (msg.content.isNotEmpty) {
          contentList.add({'type': 'text', 'text': msg.content});
        }
        if (msg.toolCalls != null) {
          for (final call in msg.toolCalls!) {
            contentList.add({
              'type': 'tool_use',
              'id': call.id,
              'name': call.name,
              'input': call.arguments,
            });
          }
        }
        convertedMessages.add({
          'role': 'assistant',
          'content': contentList.isNotEmpty ? contentList : msg.content,
        });
      } else if (msg.role == MessageRole.tool) {
        convertedMessages.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': msg.toolCallId,
              'content': msg.content,
            }
          ]
        });
      }
    }

    final requestBody = <String, dynamic>{
      'model': modelName,
      'messages': convertedMessages,
      'max_tokens': maxTokens ?? 4096,
      'temperature': temperature,
      if (systemPrompt != null) 'system': systemPrompt,
      if (stopSequences != null) 'stop_sequences': stopSequences,
    };

    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools.map((t) {
        return {
          'name': t.name,
          'description': t.description,
          'input_schema': {
            'type': 'object',
            'properties': {
              for (final p in t.parameters)
                p.name: {
                  'type': p.type,
                  'description': p.description,
                },
            },
            'required': t.parameters
                .where((p) => p.required)
                .map((p) => p.name)
                .toList(),
          },
        };
      }).toList();
    }

    final response = await _httpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': apiVersion,
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Anthropic API error (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = json['content'] as List? ?? [];
    final textParts = <String>[];
    final toolCalls = <ToolCall>[];

    for (final item in contentList) {
      if (item is Map<String, dynamic>) {
        final type = item['type'] as String?;
        if (type == 'text') {
          textParts.add((item['text'] as String?) ?? '');
        } else if (type == 'tool_use') {
          toolCalls.add(ToolCall(
            id: (item['id'] as String?) ?? 'tool_${DateTime.now().microsecondsSinceEpoch}',
            name: (item['name'] as String?) ?? 'unknown',
            arguments: (item['input'] as Map<String, dynamic>?) ?? {},
          ));
        }
      }
    }

    final usageJson = json['usage'] as Map<String, dynamic>?;
    final usage = TokenUsage(
      promptTokens: (usageJson?['input_tokens'] as int?) ?? 0,
      completionTokens: (usageJson?['output_tokens'] as int?) ?? 0,
      totalTokens: ((usageJson?['input_tokens'] as int?) ?? 0) +
          ((usageJson?['output_tokens'] as int?) ?? 0),
    );

    return ModelResponse(
      text: textParts.join('\n'),
      toolCalls: toolCalls,
      finishReason: (json['stop_reason'] as String?) ?? 'stop',
      usage: usage,
      rawResponse: json,
    );
  }
}
