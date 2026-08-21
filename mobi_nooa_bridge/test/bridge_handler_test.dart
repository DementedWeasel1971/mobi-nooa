import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_nooa_bridge/main.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  test('buildMethodCallHandler forwards decoded JSON into the dispatcher', () async {
    final dispatcher = AgentBridgeDispatcher.withDefaults();
    final handler = buildMethodCallHandler(dispatcher);

    final result = await handler(
      const MethodCall('handle', {'action': 'listAgents'}),
    );

    expect(result, isA<Map<String, dynamic>>());
    expect(
      (result as Map<String, dynamic>)['agents'],
      contains('GeneralMobileAgent'),
    );
  });

  test('buildMethodCallHandler forwards runAgentLoop, replaySession, and telemetry actions', () async {
    final dispatcher = AgentBridgeDispatcher.withDefaults();
    final handler = buildMethodCallHandler(dispatcher);

    // 1. runAgentLoop
    final runResult = await handler(
      const MethodCall('handle', {
        'action': 'runAgentLoop',
        'sessionId': 'flutter_bridge_test_01',
        'agentName': 'GeneralMobileAgent',
        'goal': 'Ping bridge',
      }),
    );
    expect(runResult, isA<Map<String, dynamic>>());
    expect((runResult as Map<String, dynamic>)['error'], isNull);
    expect(runResult['result'], isNotNull);

    // 2. replaySession
    final replayResult = await handler(
      const MethodCall('handle', {
        'action': 'replaySession',
        'sessionId': 'flutter_bridge_test_01',
        'stepIndex': 1,
      }),
    );
    expect(replayResult, isA<Map<String, dynamic>>());
    expect((replayResult as Map<String, dynamic>)['sessionId'], equals('flutter_bridge_test_01'));

    // 3. getDeviceTelemetry
    final telResult = await handler(
      const MethodCall('handle', {'action': 'getDeviceTelemetry'}),
    );
    expect(telResult, isA<Map<String, dynamic>>());
    expect((telResult as Map<String, dynamic>)['telemetry'], isNotNull);

    // 4. assessBudget
    final budgetResult = await handler(
      const MethodCall('handle', {'action': 'assessBudget'}),
    );
    expect(budgetResult, isA<Map<String, dynamic>>());
    expect((budgetResult as Map<String, dynamic>)['budget'], isNotNull);
  });

  test('buildMethodCallHandler rejects unknown platform-channel methods', () {
    final dispatcher = AgentBridgeDispatcher.withDefaults();
    final handler = buildMethodCallHandler(dispatcher);

    expect(
      () => handler(const MethodCall('somethingElse', {})),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
