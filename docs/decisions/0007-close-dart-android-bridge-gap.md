# ADR 0007: Close the Dart↔Android bridge gap via a headless Flutter engine + MethodChannel, with a pure-Dart JSON dispatcher as the seam

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

`DESIGN.md`'s open questions and the initial architecture review both
flagged the same gap: `MobiNooaService.runAgentLoop` and
`MobiNooaWorker.doWork` (Kotlin) had a comment ("Interop with the mobi_nooa
Dart engine...") but no actual call into the Dart engine, and
`OnDeviceModelEngine.kt` returned a hardcoded fake string. A concrete
mechanism had to be chosen and wired.

### Why the alternatives don't work for "Dart running on Android, called from Kotlin"

- **`dart:ffi` + a hand-rolled Dart embedder**: the standalone Dart SDK does
  not officially support AOT-compiling Dart to Android target ABIs and
  exposing entry points to a native host outside of the Flutter engine.
  Building a custom Dart embedder (using `dart_api.h` / `Dart_Initialize`)
  is a large, fragile undertaking duplicating what Flutter's engine already
  does, and isn't realistically completable/verifiable in a text-editing
  session without the Dart/Flutter engine build toolchain.
- **Subprocess + local socket** (`dart compile exe` run as a child
  process): `dart compile exe` targets desktop/server platforms, not
  Android ABIs, via the stock Dart SDK. It cannot produce an
  Android-runnable native executable without Flutter's engine and NDK
  toolchain, so this path is not viable for on-device Android execution.
- **Full manual reimplementation in Kotlin**: would abandon `mobi_nooa_core`
  entirely for the Android target and duplicate every subsystem
  (agent/loop/heap/strategies/memory/storage/security/tools) in Kotlin —
  defeats the purpose of having a shared Dart core.

**Flutter's engine embedding (the officially supported "add-to-app"
pattern) is the only currently-practical way to execute real Dart/AOT code
inside an Android process.** It does not require a Flutter *UI* — a
`FlutterEngine` can run headless, executing a Dart entry point and
communicating purely via `MethodChannel`/`BasicMessageChannel`, which is
exactly the shape `MobiNooaService` (foreground loop) and `MobiNooaWorker`
(scheduled background task) need.

## Decision

1. **Keep `mobi_nooa_core` Flutter-free** (unchanged invariant). Add a new,
   pure-Dart `AgentBridgeDispatcher`
   (`mobi_nooa_core/lib/src/bridge/agent_bridge_dispatcher.dart`) that
   accepts a `Map<String, dynamic>` JSON request
   (`{"action": "runAgentLoop", "agentName": ..., "goal": ..., "inputs":
   {...}, "model": {"provider": ..., "apiKey": ...}}`) and returns a JSON
   response (`{"result": ..., "trace": [...]}` or `{"error": ...}`). This
   is the actual "bridge protocol" and is fully testable with `dart test`
   without Flutter or Android tooling — see
   `mobi_nooa_core/test/agent_bridge_dispatcher_test.dart`.
2. **Introduce a new, separate Flutter package** that depends on both
   `flutter` and `mobi_nooa_core` (path dependency) and does nothing more
   than decode incoming platform-channel calls, forward them to
   `AgentBridgeDispatcher.handle`, and encode the response back. This
   package is intentionally thin and isolated so the "no Flutter in core"
   invariant is never at risk of being violated by future changes.
3. **Kotlin side**: `MobiNooaService` and `MobiNooaWorker` own a
   `FlutterEngine`, execute the bridge package's Dart entry point headless
   (no `FlutterActivity`/UI), and call `MethodChannel.invokeMethod(...)`
   with the same JSON shape the dispatcher expects.

## Consequences / what remains a manual local step

This ADR and the `AgentBridgeDispatcher` implementation close the
**protocol and Dart-side** half of the gap completely, and it is verified
in this repo (`dart analyze` clean, `dart test` passing, including 5 new
bridge-dispatcher tests). The **Flutter engine embedding and generated
Android glue** cannot be completed or verified inside this environment,
because:

- No Flutter SDK is installed here (only the stock Dart SDK is available).
- `android_mobi_nooa` has no root Gradle project (no `settings.gradle.kts`,
  no `gradlew` wrapper) to attach a Flutter "add-to-app" module to.
- No Android SDK/NDK or emulator/device is available to build or run an
  APK in this session.

Concretely, to finish wiring this up on a machine with the Flutter SDK
installed:

1. Run `flutter create -t module mobi_nooa_bridge` at the repo root (or
   inside a `bridge/` directory) and set its `pubspec.yaml` to depend on
   `mobi_nooa_core` via a relative path.
2. Replace the generated `lib/main.dart` with a headless entry point that
   constructs an `AgentBridgeDispatcher.withDefaults()`, registers a
   `MethodChannel('com.mobi.nooa/agent_bridge')` handler, and forwards each
   call to `dispatcher.handle(...)`.
3. Follow Flutter's "Add to existing app" instructions to generate the
   Android embedding (`.android/`) and wire it into a real Gradle root
   project alongside `android_mobi_nooa`.
4. Update `MobiNooaService.kt`/`MobiNooaWorker.kt` (already updated in this
   change to the intended shape) to point at the generated Flutter module.

This ADR supersedes the "bridge mechanism" open question in `DESIGN.md`;
the remaining Flutter-tooling-dependent steps are tracked as a checklist
here rather than as an unresolved design question.
