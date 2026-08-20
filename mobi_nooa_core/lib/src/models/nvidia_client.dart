import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// NVIDIA NIM & NVIDIA AI Foundation Models client adapter.
///
/// Connects to NVIDIA NIM endpoints (default: `https://integrate.api.nvidia.com/v1`)
/// with support for Llama 3.3 (`meta/llama-3.3-70b-instruct`), Llama 3.1 Nemotron
/// (`nvidia/llama-3.1-nemotron-70b-instruct`), GLM (`z-ai/glm-5.2`), and on-premise
/// NVIDIA NIM enterprise microservice deployments.
class NvidiaClient implements ModelClient {
  final String apiKey;
  @override
  final String modelName;
  final String baseUrl;
  final http.Client _httpClient;

  NvidiaClient({
    required this.apiKey,
    this.modelName = 'meta/llama-3.3-70b-instruct',
    this.baseUrl = 'https://integrate.api.nvidia.com/v1',
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

    http.Response? response;
    int retries = 0;
    const maxRetries = 3;

    while (retries <= maxRetries) {
      response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 429 || response.statusCode == 503) {
        if (retries < maxRetries) {
          retries++;
          final backoffMs = 1500 * (1 << (retries - 1));
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
      }
      break;
    }

    if (response == null || response.statusCode != 200) {
      throw Exception(
        'NVIDIA API error (${response?.statusCode}): ${response?.body}',
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

  /// Queries the NVIDIA NIM endpoint to fetch the list of all available models.
  Future<List<String>> listAvailableModels() async {
    return fetchModels(apiKey: apiKey, baseUrl: baseUrl, httpClient: _httpClient);
  }

  /// Static helper to fetch available model IDs from any NVIDIA NIM / OpenAI-compatible endpoint.
  static Future<List<String>> fetchModels({
    required String apiKey,
    String baseUrl = 'https://integrate.api.nvidia.com/v1',
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final url = Uri.parse('$baseUrl/models');

    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to query models from NVIDIA endpoint (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List? ?? [];
    final modelIds = <String>[];
    for (final item in data) {
      if (item is Map<String, dynamic> && item.containsKey('id')) {
        modelIds.add(item['id'] as String);
      }
    }
    modelIds.sort();
    return modelIds;
  }
}
