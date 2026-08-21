---
name: test-mobi-nooa
description: 'Comprehensive guidelines, runbooks, and recipes for the 4-tier testing pyramid and strict TDD methodology in mobi-nooa across Dart core, Flutter bridge, Android Kotlin library, and live on-device test harnesses.'
---

# Testing mobi-nooa (4-Tier Testing Pyramid & TDD Runbook)

Use this skill when authoring new agents, coding tools, execution strategies, model clients, harness capabilities, or Android bridge actions to ensure 100% test coverage and compliance with NOOA design invariants.

---

## 🏛️ 1. The 4-Tier Testing Pyramid

`mobi-nooa` enforces a four-tier testing hierarchy that guarantees rapid in-memory CI execution while verifying true hardware, MethodChannel, and UI behavior:

```
           / \
          / 4 \     Tier 4: Live On-Device Instrumentation & UI Tests (ADB / Hardware)
         /-----\
        /   3   \   Tier 3: Android Native Kotlin JVM Unit Tests (Domain / UDF ViewModels)
       /---------\
      /     2     \ Tier 2: Headless Flutter Bridge MethodChannel Tests (Platform Boundary)
     /-------------\
    /       1       \ Tier 1: Pure In-Memory Dart Core Unit Tests (19 Subsystems, Mock Clients)
   /-----------------\
```

---

## ⚡ Tier 1: Pure In-Memory Dart Core Unit Tests (`mobi_nooa_core/test/`)

- **Characteristics**: 0 network calls, 0 device/emulator requirements, ultra-fast (<2s for 114+ tests).
- **Location**: `mobi_nooa_core/test/`

### Writing Mock Clients for Deterministic Testing

```dart
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  test('Agent executes multi-step tool call and synthesizes answer', () async {
    final mockModel = MockConfigurableModelClient(
      modelName: 'mock-cloud',
      responses: [
        // Step 1: LLM decides to call a tool
        ModelResponse(
          text: 'Inspecting device battery level...',
          toolCalls: [
            ToolCall(id: 'call_01', name: 'getBatteryStatus', arguments: {}),
          ],
        ),
        // Step 2: LLM receives tool output and returns final answer
        ModelResponse(
          text: '{"thought": "Battery is nominal", "answer": "Battery level is 85%"}',
        ),
      ],
    );

    final agent = Quickstart.createAgent(
      () => AutonomousDeviceAgent(),
      model: mockModel,
    );

    final result = await agent.ellipsis<String>('Triage battery health', maxSteps: 3);
    expect(result, contains('85%'));
  });
}
```

### 12-Permutation Fallback Cascade Test Recipe

When adding or testing model failover logic, always test the 12 scenario permutations:
1. **Nominal Primary**: 0 failures, 0 latency overhead.
2. **In-Tier Transient Retry**: Transient `SocketException` recovered on retry 1 without escalating to secondary.
3. **HTTP 503 Service Unavailable**: Primary retries exhausted $\rightarrow$ Cascades to Secondary $\rightarrow$ Emits `providerError`, `providerFallback`, `providerRecovered`.
4. **Timeout (`TimeoutException`)**: Slow primary exceeds `providerTimeout` $\rightarrow$ Cascades to Secondary.
5. **4-Tier N-Way Chain**: Tier 1 (429 RateLimit) $\rightarrow$ Tier 2 (Timeout) $\rightarrow$ Tier 3 (502 ServerError) $\rightarrow$ Tier 4 (Local Quantized Model).
6. **All Providers Exhausted**: All candidates fail $\rightarrow$ Emits `allExhausted`, throws `AllProvidersExhaustedException`.
7. **Mid-Trajectory Tool Fallback**: Step 1 tool call succeeds on Primary $\rightarrow$ Step 2 crashes $\rightarrow$ Secondary continues with full conversation history.
8. **Schema Preservation**: Tool definitions and OpenAPI schemas forwarded identically.
9. **Reasoning Extraction**: DeepSeek-R1 `<think>` tokens parsed into `reasoningContent`.
10. **Bridge Dispatcher Parsing**: Dynamic JSON configuration instantiated correctly.
11. **Single-Element Pass-Through**: Single provider acts as transparent zero-overhead wrapper.
12. **State Reset**: `cascade.reset()` restores active index to 0.

---

## 🌉 Tier 2: Headless Flutter Bridge MethodChannel Tests (`mobi_nooa_bridge/test/`)

- **Characteristics**: Verifies platform boundary translation between Android Kotlin `MethodChannel` and Dart `AgentBridgeDispatcher`.
- **Location**: `mobi_nooa_bridge/test/`

```dart
test('buildMethodCallHandler forwards decoded JSON into the dispatcher', () async {
  final dispatcher = AgentBridgeDispatcher.withDefaults();
  final handler = buildMethodCallHandler(dispatcher);

  final result = await handler(
    const MethodCall('handle', {
      'action': 'runAgentLoop',
      'agentName': 'GeneralMobileAgent',
      'goal': 'Ping bridge',
    }),
  );

  expect(result, isA<Map<String, dynamic>>());
  expect((result as Map<String, dynamic>)['error'], isNull);
});
```

---

## 🤖 Tier 3: Android Native Kotlin Architecture Tests (`android_mobi_nooa/src/test/`)

- **Characteristics**: Fast JVM unit tests validating Domain Use Cases, Clean Architecture, and UDF MVI ViewModels using `FakeAgentRepository`.
- **Location**: `android_mobi_nooa/src/test/kotlin/com/mobi/nooa/`

```kotlin
@Test
fun testAgentExecutionViewModel_TracksReasoningAndSteps() = runTest(testDispatcher) {
    val fakeRepo = FakeAgentRepository()
    val executeUseCase = ExecuteAgentTaskUseCase(fakeRepo)
    val viewModel = AgentExecutionViewModel(executeUseCase, fakeRepo)

    viewModel.executeTask("AutonomousDeviceAgent", "Triage device")
    testScheduler.advanceUntilIdle()

    val state = viewModel.uiState.value
    assertTrue(state.isSuccess)
    assertEquals(3, state.stepCount)
    assertEquals(1, state.heapHandles.size)
}
```

---

## 📱 Tier 4: Live On-Device Integration Tests (`scratch/test_device_cascade_permutations.ps1`)

- **Characteristics**: Automated live ADB execution against a running Android emulator (`emulator-5554`) or physical device.
- **Location**: `scratch/test_device_cascade_permutations.ps1`

```powershell
# Run automated on-device test runner
powershell -ExecutionPolicy Bypass -File scratch/test_device_cascade_permutations.ps1
```

**Assertions Verified**:
1. Activity launches on device foreground without crashing.
2. User tab navigation and button inputs dispatch across MethodChannel.
3. Cloud provider failure correctly triggers fallback to local on-device quantized model.
4. UI renders `tvStreamFallbackBanner`, `tvStreamConsole`, and `✓ EXECUTION COMPLETE`.

---

## 🔄 Strict TDD Workflow (Red -> Green -> Refactor & Secure)

1. **RED (Write Failing Test First)**:
   - Identify the expected state mutations (`getState`), heap handles (`#ref_xxx`), and tool return formats.
   - Author a test in `mobi_nooa_core/test/` or `android_mobi_nooa/src/test/` asserting this behavior with `MockConfigurableModelClient`.
2. **GREEN (Implement Minimum Behavior)**:
   - Implement the agent action, harness method, or repository call.
   - Run `dart test` or `./gradlew test` until the assertion passes.
3. **REFACTOR & SECURE**:
   - Validate security guardrails with `AstGuardrails.validate` or `PermissionManager.authorize`.
   - Wrap large return payloads in `ObjectHeap.maybeWrap`.
   - Run static analysis (`dart analyze`, `flutter analyze`) to ensure 100% clean output.

---

## 🚀 Quick Execution Cheatsheet

```powershell
# 1. Run all Dart core unit tests (114+ tests)
cd mobi_nooa_core
dart analyze
dart test --exclude-tags live

# 2. Run Flutter bridge shim tests
cd ../mobi_nooa_bridge
flutter analyze
flutter test

# 3. Run Android Kotlin JVM tests
cd ../android_mobi_nooa
./gradlew :android_mobi_nooa:testDebugUnitTest

# 4. Run full end-to-end device integration test
powershell -ExecutionPolicy Bypass -File scratch/test_device_cascade_permutations.ps1
```
