import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// Headless entrypoint executed by `MobiNooaBridge.kt` inside a UI-less
/// `FlutterEngine` embedded from `android_mobi_nooa`.
///
/// This module intentionally has no visible UI. Its only job is to sit on
/// the `com.mobi.nooa/agent_bridge` [MethodChannel], decode each incoming
/// call's JSON-shaped arguments, forward them to
/// [AgentBridgeDispatcher.handle] (from `mobi_nooa_core`, which stays
/// Flutter-free), and return the JSON-shaped response back across the
/// channel. See `docs/decisions/0007-close-dart-android-bridge-gap.md` for
/// the full rationale.
const channelName = 'com.mobi.nooa/agent_bridge';

/// Builds the [MethodChannel] call handler that forwards decoded JSON
/// requests into [dispatcher]. Extracted as a standalone function so it can
/// be unit-tested without spinning up the platform channel plumbing (this
/// module has no UI to test against).
Future<dynamic> Function(MethodCall) buildMethodCallHandler(
  AgentBridgeDispatcher dispatcher,
) {
  return (MethodCall call) async {
    if (call.method != 'handle') {
      throw MissingPluginException('Unknown method ${call.method}');
    }

    final request = Map<String, dynamic>.from(call.arguments as Map);
    return dispatcher.handle(request);
  };
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final dispatcher = AgentBridgeDispatcher.withDefaults();
  const channel = MethodChannel(channelName);
  channel.setMethodCallHandler(buildMethodCallHandler(dispatcher));
}
