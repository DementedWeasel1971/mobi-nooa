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

  test('buildMethodCallHandler rejects unknown platform-channel methods', () {
    final dispatcher = AgentBridgeDispatcher.withDefaults();
    final handler = buildMethodCallHandler(dispatcher);

    expect(
      () => handler(const MethodCall('somethingElse', {})),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
