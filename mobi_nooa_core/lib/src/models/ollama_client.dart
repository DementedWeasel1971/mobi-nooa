import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// Ollama model client for local self-hosted or LAN LLMs.
class OllamaClient implements ModelClient {
  @override
  final String modelName;
  final String baseUrl;
  final http.Client _httpClient;

  OllamaClient({
    this.modelName = 'llama3.2',
    this.baseUrl = 'http://localhost:11434',
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
    final url = Uri.parse('$baseUrl/api/chat');

    final requestBody = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': false,
      'options': {
        'temperature': temperature,
        if (maxTokens != null) 'num_predict': maxTokens,
        if (stopSequences != null) 'stop': stopSequences,
      },
    };

    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools.map((t) => t.toJson()).toList();
    }

    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Ollama API error (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final message = json['message'] as Map<String, dynamic>? ?? {};
    final content = (message['content'] as String?) ?? '';

    final toolCalls = <ToolCall>[];
    final rawToolCalls = message['tool_calls'] as List? ?? [];
    for (final tc in rawToolCalls) {
      if (tc is Map<String, dynamic>) {
        toolCalls.add(ToolCall.fromJson(tc));
      }
    }

    final usage = TokenUsage(
      promptTokens: (json['prompt_eval_count'] as int?) ?? 0,
      completionTokens: (json['eval_count'] as int?) ?? 0,
      totalTokens: ((json['prompt_eval_count'] as int?) ?? 0) +
          ((json['eval_count'] as int?) ?? 0),
    );

    return ModelResponse(
      text: content,
      toolCalls: toolCalls,
      finishReason: (json['done_reason'] as String?) ?? 'stop',
      usage: usage,
      rawResponse: json,
    );
  }
}
