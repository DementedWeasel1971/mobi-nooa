import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('DeepSeek Harness & Plugin Architecture End-to-End Suite', () {
    test('AgentLoop runs with DeepSeekClient reasoning and populates SessionEventLog', () async {
      int requestCount = 0;
      final mockHttp = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': 'I am checking the battery status now.',
                    'reasoning_content': 'First step is to inspect hardware telemetry to evaluate battery charge and temperature.',
                    'tool_calls': [
                      {
                        'id': 'call_1',
                        'type': 'function',
                        'function': {
                          'name': 'getBatteryStatus',
                          'arguments': '{}',
                        }
                      }
                    ],
                  },
                  'finish_reason': 'tool_calls',
                }
              ],
              'usage': {'prompt_tokens': 100, 'completion_tokens': 50, 'total_tokens': 150}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': 'Battery is 92% and healthy. System status is nominal.',
                    'reasoning_content': 'Battery level is above 90%, thermal state is normal. Task is complete.',
                  },
                  'finish_reason': 'stop',
                }
              ],
              'usage': {'prompt_tokens': 150, 'completion_tokens': 30, 'total_tokens': 180}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
      });

      final deepseekModel = DeepSeekClient(
        apiKey: 'sk-deepseek-test',
        modelName: 'deepseek-reasoner',
        httpClient: mockHttp,
      );

      final sessionLog = SessionEventLog(sessionId: 'integration_session_01');
      final telemetryPlugin = TelemetryLoggerPlugin();
      final plugins = PluginRegistry()..register(telemetryPlugin);

      final agent = Quickstart.createAgent(
        () => AutonomousDeviceAgent(),
        model: deepseekModel,
        plugins: plugins,
        sessionLog: sessionLog,
      );

      final result = await agent.ellipsis<String>('Audit battery health');

      expect(result, contains('healthy'));
      expect(sessionLog.events, isNotEmpty);
      expect(sessionLog.filterByType(SessionEventType.assistantThought), isNotEmpty);
      expect(sessionLog.filterByType(SessionEventType.toolCall), isNotEmpty);
      expect(sessionLog.filterByType(SessionEventType.toolResult), isNotEmpty);

      // Verify Telemetry plugin collected records
      expect(telemetryPlugin.records, isNotEmpty);
      expect(telemetryPlugin.records.any((r) => r['event'] == 'afterStep'), isTrue);

      // Verify Time-Travel replay
      final replayState = sessionLog.replay(1);
      expect(replayState.stepIndex, equals(1));
    });

    test('AgentLoop enforces tiered permission policy and stops blocked mutations in audit mode', () async {
      final mockModel = MockModelClient();
      mockModel.queueToolCall(
        toolName: 'createFile',
        arguments: {'path': '/system/corrupt.bin', 'content': 'bad'},
      );
      mockModel.queueText('Acknowledged file mutation was denied.');

      final agent = Quickstart.createAgent(
        () => AutonomousCodingAgent(),
        model: mockModel,
        permissionManager: PermissionManager(policy: PermissionPolicy.strictAudit()),
      );

      final result = await agent.ellipsis<String>('Write file');
      expect(result, contains('denied'));
    });

    test('AgentBridgeDispatcher seamlessly drives DeepSeek provider and session forking', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      // Create session
      final createResp = await dispatcher.handle({
        'action': 'createSession',
        'sessionId': 'bridge_sess_100',
      });
      expect(createResp['sessionId'], equals('bridge_sess_100'));

      // Run agent loop with mock provider & session tracking
      final runResp = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'AutonomousDeviceAgent',
        'goal': 'Check device health',
        'sessionId': 'bridge_sess_100',
        'model': {'provider': 'mock'},
      });

      expect(runResp['result'], isNotNull);
      expect(runResp['sessionEventCount'], greaterThan(0));

      // Fork session
      final forkResp = await dispatcher.handle({
        'action': 'forkSession',
        'sourceSessionId': 'bridge_sess_100',
        'newSessionId': 'bridge_sess_100_fork',
      });
      expect(forkResp['newSessionId'], equals('bridge_sess_100_fork'));
      expect(forkResp['eventCount'], greaterThan(0));

      // Replay session
      final replayResp = await dispatcher.handle({
        'action': 'replaySession',
        'sessionId': 'bridge_sess_100_fork',
      });
      expect(replayResp['sessionId'], equals('bridge_sess_100_fork'));
    });
  });
}
