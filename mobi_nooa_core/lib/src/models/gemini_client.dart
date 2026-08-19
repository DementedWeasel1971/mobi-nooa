import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// Gemini LLM adapter connecting to Google AI Gemini models.
class GeminiClient implements ModelClient {
  final String apiKey;
  @override
  final String modelName;
  final String baseUrl;
  final http.Client _httpClient;

  GeminiClient({
    required this.apiKey,
    this.modelName = 'gemini-1.5-flash',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
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
    final url = Uri.parse(
      '$baseUrl/models/$modelName:generateContent?key=$apiKey',
    );

    // Extract system instructions if any
    String? systemInstructionText;
    final contents = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == MessageRole.system) {
        systemInstructionText = msg.content;
      } else if (msg.role == MessageRole.user) {
        contents.add({
          'role': 'user',
          'parts': [{'text': msg.content}],
        });
      } else if (msg.role == MessageRole.assistant) {
        final parts = <Map<String, dynamic>>[];
        if (msg.content.isNotEmpty) {
          parts.add({'text': msg.content});
        }
        if (msg.toolCalls != null) {
          for (final call in msg.toolCalls!) {
            parts.add({
              'functionCall': {
                'name': call.name,
                'args': call.arguments,
              }
            });
          }
        }
        contents.add({'role': 'model', 'parts': parts});
      } else if (msg.role == MessageRole.tool) {
        contents.add({
          'role': 'function',
          'parts': [
            {
              'functionResponse': {
                'name': msg.name ?? 'tool',
                'response': {'result': msg.content},
              }
            }
          ]
        });
      }
    }

    final requestBody = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        if (maxTokens != null) 'maxOutputTokens': maxTokens,
        if (stopSequences != null) 'stopSequences': stopSequences,
      },
    };

    if (systemInstructionText != null) {
      requestBody['systemInstruction'] = {
        'parts': [{'text': systemInstructionText}],
      };
    }

    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = [
        {
          'functionDeclarations': tools.map((t) {
            return {
              'name': t.name,
              'description': t.description,
              'parameters': {
                'type': 'OBJECT',
                'properties': {
                  for (final p in t.parameters)
                    p.name: {
                      'type': p.type.toUpperCase(),
                      'description': p.description,
                    },
                },
                'required': t.parameters
                    .where((p) => p.required)
                    .map((p) => p.name)
                    .toList(),
              },
            };
          }).toList()
        }
      ];
    }

    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List? ?? [];
    if (candidates.isEmpty) {
      return ModelResponse(text: '', finishReason: 'empty');
    }

    final first = candidates.first as Map<String, dynamic>;
    final contentObj = first['content'] as Map<String, dynamic>? ?? {};
    final parts = contentObj['parts'] as List? ?? [];

    final textParts = <String>[];
    final toolCalls = <ToolCall>[];

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        if (part.containsKey('text')) {
          textParts.add(part['text'] as String);
        }
        if (part.containsKey('functionCall')) {
          final funcCall = part['functionCall'] as Map<String, dynamic>;
          toolCalls.add(ToolCall(
            id: 'call_${DateTime.now().microsecondsSinceEpoch}',
            name: funcCall['name'] as String,
            arguments: (funcCall['args'] as Map<String, dynamic>?) ?? {},
          ));
        }
      }
    }

    final usageMetadata = json['usageMetadata'] as Map<String, dynamic>?;
    final usage = TokenUsage(
      promptTokens: (usageMetadata?['promptTokenCount'] as int?) ?? 0,
      completionTokens: (usageMetadata?['candidatesTokenCount'] as int?) ?? 0,
      totalTokens: (usageMetadata?['totalTokenCount'] as int?) ?? 0,
    );

    return ModelResponse(
      text: textParts.join('\n'),
      toolCalls: toolCalls,
      finishReason: (first['finishReason'] as String?) ?? 'stop',
      usage: usage,
      rawResponse: json,
    );
  }
}
