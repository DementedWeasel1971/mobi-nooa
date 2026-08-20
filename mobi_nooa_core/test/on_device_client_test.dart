import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('OnDeviceModelClient Prompt Formatting & Generation', () {
    final messages = [
      ModelMessage(role: MessageRole.system, content: 'You are a mobile agent.'),
      ModelMessage(role: MessageRole.user, content: 'Check device battery.'),
      ModelMessage(role: MessageRole.assistant, content: 'Battery is at 95%.'),
      ModelMessage(role: MessageRole.tool, content: 'Tool execution succeeded.'),
    ];

    test('formats prompt with Llama 3 headers by default', () {
      final client = OnDeviceModelClient();
      final prompt = client.formatPrompt(messages);

      expect(prompt, contains('<|begin_of_text|>'));
      expect(prompt, contains('<|start_header_id|>system<|end_header_id|>\n\nYou are a mobile agent.<|eot_id|>'));
      expect(prompt, contains('<|start_header_id|>user<|end_header_id|>\n\nCheck device battery.<|eot_id|>'));
      expect(prompt, contains('<|start_header_id|>assistant<|end_header_id|>\n\nBattery is at 95%.<|eot_id|>'));
      expect(prompt, endsWith('<|start_header_id|>assistant<|end_header_id|>\n\n'));
    });

    test('formats prompt with ChatML tokens when template is chatMl', () {
      final client = OnDeviceModelClient(template: PromptTemplate.chatMl);
      final prompt = client.formatPrompt(messages);

      expect(prompt, contains('<|im_start|>system\nYou are a mobile agent.<|im_end|>'));
      expect(prompt, contains('<|im_start|>user\nCheck device battery.<|im_end|>'));
      expect(prompt, contains('<|im_start|>assistant\nBattery is at 95%.<|im_end|>'));
      expect(prompt, endsWith('<|im_start|>assistant\n'));
    });

    test('formats prompt with Gemma tokens when template is gemma', () {
      final client = OnDeviceModelClient(template: PromptTemplate.gemma);
      final prompt = client.formatPrompt(messages);

      expect(prompt, contains('<start_of_turn>user\nYou are a mobile agent.<end_of_turn>'));
      expect(prompt, contains('<start_of_turn>model\nBattery is at 95%.<end_of_turn>'));
      expect(prompt, endsWith('<start_of_turn>model\n'));
    });

    test('formats prompt with raw delimiters when template is raw', () {
      final client = OnDeviceModelClient(template: PromptTemplate.raw);
      final prompt = client.formatPrompt(messages);

      expect(prompt, contains('<|system|>\nYou are a mobile agent.\n<|end|>'));
      expect(prompt, contains('<|user|>\nCheck device battery.\n<|end|>'));
      expect(prompt, endsWith('<|assistant|>\n'));
    });

    test('executes custom bridge callback with parameters', () async {
      String? capturedPrompt;
      double? capturedTemp;
      int? capturedMax;
      List<String>? capturedStops;

      final client = OnDeviceModelClient(
        template: PromptTemplate.llama3,
        bridge: (prompt, {temperature = 0.2, maxTokens, stopSequences}) async {
          capturedPrompt = prompt;
          capturedTemp = temperature;
          capturedMax = maxTokens;
          capturedStops = stopSequences;
          return 'Local inference success';
        },
      );

      final response = await client.generate(
        messages: [
          ModelMessage(role: MessageRole.user, content: 'Hello mobile!'),
        ],
        temperature: 0.7,
        maxTokens: 512,
      );

      expect(response.text, equals('Local inference success'));
      expect(capturedPrompt, contains('Hello mobile!'));
      expect(capturedTemp, equals(0.7));
      expect(capturedMax, equals(512));
      expect(capturedStops, contains('<|eot_id|>'));
      expect(response.usage.totalTokens, isPositive);
    });

    test('AgentBridgeDispatcher executes agent loop with on_device provider', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final response = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'GeneralMobileAgent',
        'goal': 'Inspect device storage.',
        'model': {
          'provider': 'on_device',
          'template': 'chatml',
          'modelName': 'llama-3.2-1b-gguf',
        },
      });

      expect(response['error'], isNull);
      expect(response['result'], isA<String>());
      expect(response['trace'], isA<List>());
    });
  });
}
