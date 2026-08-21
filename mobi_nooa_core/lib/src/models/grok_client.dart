import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'model_client.dart';

/// xAI Grok Model Provider Client.
///
/// Connects to xAI's API endpoint (`https://api.x.ai/v1`) supporting Grok models
/// (`grok-2-1212`, `grok-2-vision-1212`, `grok-beta`, `grok-3`, `grok-4.6`).
/// Faithfully extracts reasoning content (`<think>` blocks or reasoning parameters)
/// and handles tool calling and prompt cache telemetry.
class GrokClient implements ModelClient {
  @override
  final String modelName;
  final String apiKey;
  final String baseUrl;
  final http.Client _httpClient;

  GrokClient({
    required this.apiKey,
    this.modelName = 'grok-2-1212',
    this.baseUrl = 'https://api.x.ai/v1',
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
    final uri = Uri.parse('$baseUrl/chat/completions');

    final payload = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (stopSequences != null && stopSequences.isNotEmpty)
        'stop': stopSequences,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'xAI Grok API Error [HTTP ${response.statusCode}]: ${response.body}',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) {
      throw Exception('Grok API returned 0 choices.');
    }

    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>? ?? {};

    String rawText = message['content'] as String? ?? '';
    String? reasoningContent = message['reasoning_content'] as String?;

    // Extract inline <think> tags if reasoning_content was not provided as a top-level field
    if (reasoningContent == null && rawText.contains('<think>')) {
      final thinkRegex = RegExp(r'<think>([\s\S]*?)<\/think>');
      final match = thinkRegex.firstMatch(rawText);
      if (match != null) {
        reasoningContent = match.group(1)?.trim();
        rawText = rawText.replaceAll(thinkRegex, '').trim();
      }
    }

    // Parse tool calls if present
    List<ToolCall>? toolCalls;
    if (message.containsKey('tool_calls') && message['tool_calls'] is List) {
      final rawCalls = message['tool_calls'] as List;
      toolCalls = rawCalls.map((tc) {
        final callMap = tc as Map<String, dynamic>;
        final fn = callMap['function'] as Map<String, dynamic>? ?? {};
        final name = fn['name'] as String? ?? '';
        final rawArgs = fn['arguments'];
        Map<String, dynamic> arguments = {};
        if (rawArgs is String && rawArgs.isNotEmpty) {
          try {
            arguments = Map<String, dynamic>.from(jsonDecode(rawArgs) as Map);
          } catch (_) {}
        } else if (rawArgs is Map) {
          arguments = Map<String, dynamic>.from(rawArgs);
        }

        return ToolCall(
          id: callMap['id'] as String? ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          arguments: arguments,
        );
      }).toList();
    }

    // Token usage telemetry
    TokenUsage usage = const TokenUsage();
    if (data.containsKey('usage') && data['usage'] is Map) {
      final u = data['usage'] as Map<String, dynamic>;
      usage = TokenUsage(
        promptTokens: (u['prompt_tokens'] as num?)?.toInt() ?? 0,
        completionTokens: (u['completion_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (u['total_tokens'] as num?)?.toInt() ?? 0,
      );
    }

    return ModelResponse(
      text: rawText,
      toolCalls: toolCalls ?? const [],
      reasoningContent: reasoningContent,
      usage: usage,
      rawResponse: data,
    );
  }
}
