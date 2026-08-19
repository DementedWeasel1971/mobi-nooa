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

## Consequences

**Update (follow-up session)**: the Flutter SDK, Android SDK/NDK, and JDK
17 were installed locally and this plan was fully executed and verified:

- `flutter create -t module mobi_nooa_bridge` was run to generate the real
  Flutter add-to-app module; the hand-written `lib/main.dart` and
  `pubspec.yaml` from the original version of this ADR were folded into the
  generated module (path dependency on `mobi_nooa_core`, `buildMethodCallHandler`
  forwarding into `AgentBridgeDispatcher.handle`). `flutter analyze` and
  `flutter test` pass (2 tests) against the real Flutter SDK.
- A minimal `app/` Gradle module (`com.android.application`) was added as
  the Flutter add-to-app "host project" — the Flutter Gradle plugin
  requires a real application module to attach to; it cannot attach
  directly to `android_mobi_nooa` (a `com.android.library` module). `app`
  depends on `android_mobi_nooa`.
- A root `settings.gradle.kts` + `build.gradle.kts` + `gradlew`/`gradle/`
  wrapper (Gradle 8.12) were added, including `android_mobi_nooa`, `app`,
  and the generated `:flutter` module (via
  `mobi_nooa_bridge/.android/include_flutter.groovy`).
  `flutter.hostAppProjectName=app` is set in `gradle.properties`.
- `android_mobi_nooa/build.gradle.kts` now depends on
  `implementation(project(":flutter"))` so `MobiNooaBridge.kt` resolves
  `FlutterEngine`/`DartExecutor`/`MethodChannel`.
- **`./gradlew :app:assembleDebug` succeeds end-to-end** and produces a
  real, installable debug APK, compiling `android_mobi_nooa` (Kotlin),
  `mobi_nooa_bridge` (Dart/Flutter), and transitively `mobi_nooa_core`
  (Dart) together for the first time.

This closes out what was previously an open manual step. Remaining
follow-ups are ordinary app-development polish, not architectural gaps:
running the APK on a real device/emulator to exercise `MobiNooaService`'s
`runAgentLoop` end-to-end with a live model provider, and iOS embedding
(out of scope — this repo targets Android only per `DESIGN.md`).

See `local.properties.example` for the `sdk.dir`/`flutter.sdk` values a new
contributor must set locally (copy to `local.properties`, which is
gitignored) to reproduce this build.

This ADR supersedes the "bridge mechanism" open question in `DESIGN.md`;
the remaining Flutter-tooling-dependent steps are tracked as a checklist
here rather than as an unresolved design question.
