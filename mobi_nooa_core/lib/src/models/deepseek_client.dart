import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// DeepSeek AI model client adapter supporting DeepSeek-V3 (`deepseek-chat`)
/// and DeepSeek-R1 (`deepseek-reasoner`).
///
/// Features:
/// - First-class reasoning extraction (`reasoning_content` and `<think>` tags).
/// - Prompt prefix caching telemetry (`prompt_cache_hit_tokens`, `prompt_cache_miss_tokens`).
/// - Function/tool calling and parameter schema compliance.
/// - Custom API base URL overrides for SiliconFlow, OpenRouter, Together, or local Ollama.
class DeepSeekClient implements ModelClient {
  final String apiKey;
  @override
  final String modelName;
  final String baseUrl;
  final http.Client _httpClient;

  static final RegExp _thinkTagRegex = RegExp(
    r'<think>([\s\S]*?)<\/think>',
    caseSensitive: false,
  );

  DeepSeekClient({
    required this.apiKey,
    this.modelName = 'deepseek-chat',
    this.baseUrl = 'https://api.deepseek.com',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double? temperature,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    final url = Uri.parse('$baseUrl/chat/completions');

    // DeepSeek-R1 (reasoner) performs best with default temp (0.6) or omitted
    final defaultTemp = modelName.contains('reasoner') ? 0.6 : 0.2;
    final effectiveTemp = temperature ?? defaultTemp;

    final requestBody = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': effectiveTemp,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (stopSequences != null && stopSequences.isNotEmpty)
        'stop': stopSequences,
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
        'DeepSeek API error (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List? ?? [];
    if (choices.isEmpty) {
      return ModelResponse(text: '', finishReason: 'empty');
    }

    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>? ?? {};
    var content = (message['content'] as String?) ?? '';
    String? reasoning = message['reasoning_content'] as String?;

    // If reasoning_content was not provided as a discrete field, extract <think> tags from content
    if ((reasoning == null || reasoning.isEmpty) && _thinkTagRegex.hasMatch(content)) {
      final match = _thinkTagRegex.firstMatch(content);
      if (match != null) {
        reasoning = match.group(1)?.trim();
        content = content.replaceFirst(_thinkTagRegex, '').trim();
      }
    }

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
      promptCacheHitTokens: usageJson?['prompt_cache_hit_tokens'] as int?,
      promptCacheMissTokens: usageJson?['prompt_cache_miss_tokens'] as int?,
    );

    return ModelResponse(
      text: content,
      reasoningContent: reasoning,
      toolCalls: toolCalls,
      finishReason: (first['finish_reason'] as String?) ?? 'stop',
      usage: usage,
      rawResponse: json,
    );
  }
}
