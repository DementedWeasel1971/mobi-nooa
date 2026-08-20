@Tags(['live'])
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

Map<String, String> loadEnv() {
  final env = <String, String>{};
  for (final path in ['.env', '../.env', 'mobi_nooa_core/.env']) {
    final file = File(path);
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx != -1) {
          final key = trimmed.substring(0, eqIdx).trim();
          final val = trimmed.substring(eqIdx + 1).trim();
          env[key] = val;
        }
      }
      break;
    }
  }
  return env;
}

void main() {
  final env = loadEnv();
  final apiKey = env['NVIDIA_API_KEY'] ?? Platform.environment['NVIDIA_API_KEY'];
  final baseUrl = env['NVIDIA_BASE_URL'] ?? 'https://integrate.api.nvidia.com/v1';
  final modelName = env['NVIDIA_MODEL'] ?? 'meta/llama-3.3-70b-instruct';

  group('NVIDIA Live API Integration', () {
    setUp(() async {
      await Future.delayed(const Duration(seconds: 2));
    });

    test('NvidiaClient generates direct completion from live NIM endpoint', () async {
      if (apiKey == null || apiKey.isEmpty || !apiKey.startsWith('nvapi-')) {
        print('Skipping live NVIDIA test: NVIDIA_API_KEY not configured.');
        return;
      }

      final client = NvidiaClient(
        apiKey: apiKey,
        baseUrl: baseUrl,
        modelName: modelName,
      );

      final response = await client.generate(
        messages: [
          ModelMessage.user('Explain in one sentence what NVIDIA NIM microservices do.'),
        ],
        maxTokens: 100,
      );

      expect(response.text, isNotEmpty);
      expect(response.finishReason, isIn(['stop', 'length', null]));
      print('Live NVIDIA Completion: ${response.text}');
      print('Token usage: ${response.usage.totalTokens} tokens');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('AutonomousDeviceAgent completes live agentic loop with tool calls via NVIDIA NIM', () async {
      if (apiKey == null || apiKey.isEmpty || !apiKey.startsWith('nvapi-')) {
        print('Skipping live NVIDIA test: NVIDIA_API_KEY not configured.');
        return;
      }

      final client = NvidiaClient(
        apiKey: apiKey,
        baseUrl: baseUrl,
        modelName: modelName,
      );

      final agent = Quickstart.createAgent(
        () => AutonomousDeviceAgent(),
        model: client,
      );

      // Execute real agentic reasoning step against NVIDIA NIM
      final result = await agent.ellipsis<String>(
        'Audit the current device battery status and network connectivity, then provide a short summary.',
        maxSteps: 5,
      );

      expect(result, isNotNull);
      expect(result.toString(), isNotEmpty);
      print('Live Agent Result from NVIDIA NIM: $result');

      // Verify that agent context and state were recorded
      expect(agent.context.tracer.events, isNotEmpty);
      print('Trace events generated: ${agent.context.tracer.events.length}');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('AgentBridgeDispatcher executes runAgentLoop with live NVIDIA model provider', () async {
      if (apiKey == null || apiKey.isEmpty || !apiKey.startsWith('nvapi-')) {
        print('Skipping live NVIDIA test: NVIDIA_API_KEY not configured.');
        return;
      }

      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final response = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'AutonomousDeviceAgent',
        'goal': 'Check device status and report health in 1 sentence.',
        'maxSteps': 5,
        'model': {
          'provider': 'nvidia',
          'apiKey': apiKey,
          'baseUrl': baseUrl,
          'modelName': modelName,
        },
      });

      print('Dispatcher Full Response: $response');
      expect(response.containsKey('result'), isTrue, reason: 'Response was: $response');
      expect(response['error'], isNull);
      expect(response['result'], isNotNull);
      expect(response['trace'], isNotEmpty);
      print('Dispatcher Bridge Response: ${response['result']}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
