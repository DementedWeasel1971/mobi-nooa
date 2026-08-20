import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('AgentBridgeDispatcher (platform bridge protocol)', () {
    test('listAgents returns registered agent names', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final response = await dispatcher.handle({'action': 'listAgents'});

      expect(response['agents'], contains('GeneralMobileAgent'));
      expect(response['agents'], contains('BenchAgent'));
    });

    test('runAgentLoop executes a registered agent with the mock model',
        () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final response = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'GeneralMobileAgent',
        'goal': 'Say hello and report status.',
        'model': {'provider': 'mock'},
      });

      expect(response['error'], isNull);
      expect(response['result'], isA<String>());
      expect(response['trace'], isA<List>());
      expect((response['trace'] as List), isNotEmpty);
    });

    test('runAgentLoop returns an error for an unknown agent name', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final response = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'NoSuchAgent',
        'goal': 'Do something.',
      });

      expect(response['error'], contains('Unknown agent'));
    });

    test('handle returns an error map for an unknown action instead of throwing',
        () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final response = await dispatcher.handle({'action': 'notARealAction'});

      expect(response['error'], contains('Unknown or missing action'));
    });

    test('custom agents and model providers can be registered', () async {
      final dispatcher = AgentBridgeDispatcher();
      dispatcher.registerAgent('GeneralMobileAgent', () => GeneralMobileAgent());
      dispatcher.registerModelProvider('mock', (config) => MockModelClient());

      expect(dispatcher.registeredAgentNames, ['GeneralMobileAgent']);

      final response = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'GeneralMobileAgent',
        'goal': 'ping',
        'model': {'provider': 'mock'},
      });

      expect(response['error'], isNull);
    });

    test('device actions and NativeBridgeDeviceHarness delegate properly',
        () async {
      final calls = <String, dynamic>{};
      final dispatcher = AgentBridgeDispatcher.withDefaults(
        deviceBridge: (action, [params]) async {
          calls[action] = params ?? true;
          if (action == 'getBatteryInfo') {
            return {'batteryLevel': 0.75, 'isCharging': true};
          }
          if (action == 'getNetworkStatus') {
            return 'cellular';
          }
          return null;
        },
      );

      final statusRes = await dispatcher.handle({'action': 'getDeviceStatus'});
      expect(statusRes['status'], isNotNull);
      expect(statusRes['status']['batteryLevel'], 0.75);
      expect(statusRes['status']['isCharging'], true);
      expect(statusRes['status']['networkType'], 'cellular');

      final notifRes = await dispatcher.handle({
        'action': 'sendNotification',
        'title': 'Test Title',
        'body': 'Test Body',
      });
      expect(notifRes['success'], isTrue);
      expect(calls['showNotification'], isNotNull);
      expect(calls['showNotification']['title'], 'Test Title');

      final vibrateRes = await dispatcher.handle({
        'action': 'vibrate',
        'durationMs': 300,
      });
      expect(vibrateRes['success'], isTrue);
      expect(calls['vibrate'], isNotNull);
      expect(calls['vibrate']['durationMs'], 300);
    });
  });
}

