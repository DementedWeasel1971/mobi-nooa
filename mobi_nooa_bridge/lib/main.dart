import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// Headless entrypoint executed by [MobiNooaBridge.kt] inside a
/// UI-less `FlutterEngine`.
///
/// This package deliberately has no widgets/UI. Its only job is to sit on
/// the `com.mobi.nooa/agent_bridge` [MethodChannel], decode each incoming
/// call's JSON-shaped arguments, forward them to
/// [AgentBridgeDispatcher.handle] (from `mobi_nooa_core`, which stays
/// Flutter-free), and return the JSON-shaped response back across the
/// channel. See `docs/decisions/0007-close-dart-android-bridge-gap.md` for
/// the full rationale and the remaining local Flutter-tooling steps needed
/// to wire this into an Android build.
const _channelName = 'com.mobi.nooa/agent_bridge';

void main() {
  WidgetsFlutterBindingLite.ensureInitialized();

  final dispatcher = AgentBridgeDispatcher.withDefaults();
  final channel = MethodChannel(_channelName);

  channel.setMethodCallHandler((call) async {
    if (call.method != 'handle') {
      throw MissingPluginException('Unknown method ${call.method}');
    }

    final request = Map<String, dynamic>.from(call.arguments as Map);
    final response = await Future<Map<String, dynamic>>.sync(
      () => dispatcher.handle(request),
    );
    return response;
  });
}

/// Minimal stand-in for `WidgetsFlutterBinding.ensureInitialized()` kept in
/// this file (rather than importing `package:flutter/widgets.dart`) so the
/// entrypoint stays obviously headless/UI-free; swap for the real
/// `WidgetsFlutterBinding.ensureInitialized()` call once this module is
/// generated/merged via `flutter create -t module`, which provides the full
/// widgets binding automatically.
class WidgetsFlutterBindingLite {
  static void ensureInitialized() {
    // The generated Flutter module's real main.dart should call
    // WidgetsFlutterBinding.ensureInitialized() here instead; left as a
    // documented no-op placeholder since this file is written ahead of that
    // scaffolding step (see ADR 0007).
  }
}
