import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('Cloud Model Providers Formatting & Serialization Suite', () {
    test('OpenAIClient formats messages, tools, and headers properly', () async {
      final client = OpenAIClient(
        apiKey: 'test-openai-key',
        modelName: 'gpt-4o',
        baseUrl: 'https://api.openai.com/v1',
      );

      expect(client.modelName, equals('gpt-4o'));
      expect(client.apiKey, equals('test-openai-key'));
      expect(client.baseUrl, equals('https://api.openai.com/v1'));
    });

    test('GeminiClient configures Google Gemini API endpoint and model parameters', () async {
      final client = GeminiClient(
        apiKey: 'test-gemini-key',
        modelName: 'gemini-1.5-pro',
      );

      expect(client.modelName, equals('gemini-1.5-pro'));
      expect(client.apiKey, equals('test-gemini-key'));
    });

    test('AnthropicClient configures Claude API endpoint and model parameters', () async {
      final client = AnthropicClient(
        apiKey: 'test-anthropic-key',
        modelName: 'claude-3-5-sonnet-20241022',
      );

      expect(client.modelName, equals('claude-3-5-sonnet-20241022'));
      expect(client.apiKey, equals('test-anthropic-key'));
    });

    test('OllamaClient configures local Ollama endpoint and model', () async {
      final client = OllamaClient(
        modelName: 'llama3:8b',
        baseUrl: 'http://localhost:11434',
      );

      expect(client.modelName, equals('llama3:8b'));
      expect(client.baseUrl, equals('http://localhost:11434'));
    });

    test('ToolDefinition toJson maps to standard OpenAPI / Function-Calling schema', () {
      final tool = ToolDefinition(
        name: 'calculateTax',
        description: 'Computes sales tax',
        parameters: [
          ToolParameter(
            name: 'amount',
            type: 'number',
            description: 'Total transaction amount',
            required: true,
          ),
          ToolParameter(
            name: 'rate',
            type: 'number',
            description: 'Tax rate percentage',
            required: false,
            defaultValue: 0.05,
          ),
        ],
      );

      final json = tool.toJson();
      expect(json['type'], equals('function'));
      expect(json['function']['name'], equals('calculateTax'));
      expect(json['function']['description'], equals('Computes sales tax'));
      final params = json['function']['parameters'] as Map<String, dynamic>;
      expect(params['type'], equals('object'));
      expect(params['properties']['amount']['type'], equals('number'));
      expect(params['required'], contains('amount'));
      expect(params['required'], isNot(contains('rate')));
    });

    test('ModelMessage handles system, user, assistant, and tool messages', () {
      final systemMsg = ModelMessage.system('You are an autonomous mobile agent.');
      expect(systemMsg.role, equals(MessageRole.system));
      expect(systemMsg.content, equals('You are an autonomous mobile agent.'));

      final userMsg = ModelMessage.user('Triage battery health');
      expect(userMsg.role, equals(MessageRole.user));

      final assistantMsg = ModelMessage.assistant(
        'Inspecting telemetry...',
        toolCalls: [
          ToolCall(id: 'call_99', name: 'getTelemetry', arguments: {'metric': 'battery'}),
        ],
      );
      expect(assistantMsg.role, equals(MessageRole.assistant));
      expect(assistantMsg.toolCalls, isNotNull);
      expect(assistantMsg.toolCalls!.first.name, equals('getTelemetry'));

      final toolMsg = ModelMessage.tool(
        content: '{"battery": 88, "charging": true}',
        toolCallId: 'call_99',
        name: 'getTelemetry',
      );
      expect(toolMsg.role, equals(MessageRole.tool));
      expect(toolMsg.toolCallId, equals('call_99'));
    });
  });
}
