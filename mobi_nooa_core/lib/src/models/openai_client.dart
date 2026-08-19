import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// OpenAI format adapter compatible with OpenAI, Groq, DeepSeek, Together, and vLLM.
class OpenAIClient implements ModelClient {
  final String apiKey;
  @override
  final String modelName;
  final String baseUrl;
  final http.Client _httpClient;

  OpenAIClient({
    required this.apiKey,
    this.modelName = 'gpt-4o',
    this.baseUrl = 'https://api.openai.com/v1',
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
    final url = Uri.parse('$baseUrl/chat/completions');

    final requestBody = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (stopSequences != null) 'stop': stopSequences,
    };

    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools.map((t) => t.toJson()).toList();
    }

    final response = await _httpClient.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List? ?? [];
    if (choices.isEmpty) {
      return ModelResponse(text: '', finishReason: 'empty');
    }

    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>? ?? {};
    final content = (message['content'] as String?) ?? '';

    final toolCalls = <ToolCall>[];
    final rawToolCalls = message['tool_calls'] as List? ?? [];
    for (final tc in rawToolCalls) {
      if (tc is Map<String, dynamic>) {
        toolCalls.add(ToolCall.fromJson(tc));
      }
    }

    final usageJson = json['usage'] as Map<String, dynamic>?;
    final usage = TokenUsage(
      promptTokens: (usageJson?['prompt_tokens'] as int?) ?? 0,
      completionTokens: (usageJson?['completion_tokens'] as int?) ?? 0,
      totalTokens: (usageJson?['total_tokens'] as int?) ?? 0,
    );

    return ModelResponse(
      text: content,
      toolCalls: toolCalls,
      finishReason: (first['finish_reason'] as String?) ?? 'stop',
      usage: usage,
      rawResponse: json,
    );
  }
}
