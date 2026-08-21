import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('DeepSeekClient', () {
    test('constructs with default model and endpoint', () {
      final client = DeepSeekClient(apiKey: 'sk-test-123');
      expect(client.modelName, equals('deepseek-chat'));
      expect(client.baseUrl, equals('https://api.deepseek.com'));
    });

    test('generates response and extracts reasoning_content for DeepSeek-R1', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.deepseek.com/chat/completions'));
        expect(request.headers['Authorization'], equals('Bearer sk-test-123'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], equals('deepseek-reasoner'));
        expect(body['messages'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'id': 'chatcmpl-12345',
            'object': 'chat.completion',
            'created': 1740000000,
            'model': 'deepseek-reasoner',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'The battery status is optimal and no triage is required.',
                  'reasoning_content': 'First, I will evaluate the device telemetry data. Thermal load is low, battery health is 98%. Therefore, no action needed.',
                },
                'finish_reason': 'stop',
              }
            ],
            'usage': {
              'prompt_tokens': 120,
              'completion_tokens': 45,
              'total_tokens': 165,
              'prompt_cache_hit_tokens': 100,
              'prompt_cache_miss_tokens': 20,
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'sk-test-123',
        modelName: 'deepseek-reasoner',
        httpClient: mockHttp,
      );

      final response = await client.generate(
        messages: [ModelMessage.user('Triage device health')],
      );

      expect(response.text, contains('optimal'));
      expect(response.reasoningContent, contains('First, I will evaluate the device telemetry'));
      expect(response.hasReasoning, isTrue);
      expect(response.usage.promptTokens, equals(120));
      expect(response.usage.promptCacheHitTokens, equals(100));
      expect(response.usage.promptCacheMissTokens, equals(20));
    });

    test('parses think tag when reasoning_content is in text body', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': '<think>\nAnalyze file system harness before writing to /data/.\n</think>\nFile write operation verified safe.',
                },
                'finish_reason': 'stop',
              }
            ],
            'usage': {'prompt_tokens': 50, 'completion_tokens': 30, 'total_tokens': 80}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'sk-test-123',
        modelName: 'deepseek-chat',
        httpClient: mockHttp,
      );

      final response = await client.generate(
        messages: [ModelMessage.user('Check permissions')],
      );

      expect(response.text, equals('File write operation verified safe.'));
      expect(response.reasoningContent, contains('Analyze file system harness'));
      expect(response.hasReasoning, isTrue);
    });

    test('handles function / tool calling in DeepSeek format', () async {
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tools'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': '',
                  'tool_calls': [
                    {
                      'id': 'call_dsh_001',
                      'type': 'function',
                      'function': {
                        'name': 'getDeviceInfo',
                        'arguments': '{"detailed": true}',
                      }
                    }
                  ],
                },
                'finish_reason': 'tool_calls',
              }
            ],
            'usage': {'prompt_tokens': 80, 'completion_tokens': 20, 'total_tokens': 100}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = DeepSeekClient(
        apiKey: 'sk-test-123',
        httpClient: mockHttp,
      );

      final response = await client.generate(
        messages: [ModelMessage.user('Get hardware info')],
        tools: [
          const ToolDefinition(
            name: 'getDeviceInfo',
            description: 'Returns mobile hardware info',
            parameters: [
              ToolParameter(
                name: 'detailed',
                type: 'boolean',
                description: 'Include detailed telemetry',
              ),
            ],
          ),
        ],
      );

      expect(response.hasToolCalls, isTrue);
      expect(response.toolCalls.first.name, equals('getDeviceInfo'));
      expect(response.toolCalls.first.arguments['detailed'], isTrue);
    });
  });
}
