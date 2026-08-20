# mobi-nooa Developer Guide

This guide covers step-by-step instructions for implementing custom agents, actions, harnesses, execution strategies, and writing automated tests in **`mobi-nooa`**.

---

## 🏗️ 1. Creating a Custom Agent

To build an agent, subclass `NooaAgent` from `package:mobi_nooa_core/mobi_nooa_core.dart`:

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class SystemAuditorAgent extends NooaAgent {
  SystemAuditorAgent()
      : super(
          name: 'SystemAuditorAgent',
          role: 'On-Device Security & Health Auditor',
          description: 'Inspects battery, network status, and writes compliance logs.',
          customPromptInstructions: 'Always verify battery level before initiating heavy network scans.',
        );

  @override
  void initAgent() {
    // 1. Initialize explicit state keys
    setState('scansCompleted', 0);
    setState('lastAuditStatus', 'pending');

    // 2. Register callable actions (tools)
    registerAction(
      name: 'runAudit',
      description: 'Executes a comprehensive health check on the device.',
      parameters: const [
        ToolParameter(
          name: 'includeNetwork',
          type: 'boolean',
          description: 'Whether to check network connectivity',
          required: false,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final checkNet = (args['includeNetwork'] as bool?) ?? false;
        final status = await context.harness.device.getStatus();

        // Mutate explicit state
        final count = (getState('scansCompleted') as int? ?? 0) + 1;
        setState('scansCompleted', count);
        setState('lastAuditStatus', 'passed');

        return {
          'battery': status.batteryLevel,
          'isCharging': status.isCharging,
          'networkChecked': checkNet,
          'scanIndex': count,
        };
      },
    );
  }
}
```

> [!IMPORTANT]
> **Lazy Tool Initialization Rule**: `initAgent()` is invoked in the super constructor before `attachContext()` is called. Never access `context` synchronously in the constructor. Use lazy getters for tools requiring harnesses:
> ```dart
> FileEditorTool? _editor;
> FileEditorTool get editor => _editor ??= FileEditorTool(fs: context.harness.fs);
> ```

---

## ⚙️ 2. Adding a New Execution Strategy

Strategies implement `ExecutionStrategy` to govern the reasoning loop:

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class CriticDebateStrategy implements ExecutionStrategy {
  @override
  String get name => 'CriticDebate';

  @override
  String get description => 'Alternates between solution proposal and adversarial critique.';

  @override
  String buildStrategyPrompt(NooaAgent agent) {
    return '''
Step 1: Propose a solution with Thought and Action.
Step 2: Act as a Critic to find potential bugs or edge cases.
Step 3: Revise solution until fully confident, then emit "Final Answer: <result>".
''';
  }

  @override
  Future<StrategyStepResult> processResponse({
    required NooaAgent agent,
    required ModelResponse modelResponse,
    required List<StepExecution> history,
  }) async {
    if (modelResponse.hasToolCalls) {
      return StrategyStepResult.continueLoop(
        thought: modelResponse.text,
        toolCalls: modelResponse.toolCalls,
      );
    }

    final text = modelResponse.text.trim();
    if (text.contains('Final Answer:')) {
      final answer = text.split('Final Answer:').last.trim();
      return StrategyStepResult.finish(answer, thought: text);
    }

    return StrategyStepResult.continueLoop(thought: text);
  }
}
```

---

## 🧪 3. Testing Your Agent

Use `MockModelClient` for deterministic unit and workflow testing:

```dart
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  test('SystemAuditorAgent completes audit workflow', () async {
    final mockModel = MockModelClient();
    mockModel.queueToolCall(
      toolName: 'runAudit',
      arguments: {'includeNetwork': true},
      thought: 'Running system audit check.',
    );
    mockModel.queueText('Audit completed successfully. All systems nominal.');

    final agent = Quickstart.createAgent(
      () => SystemAuditorAgent(),
      model: mockModel,
    );

    final result = await agent.ellipsis<String>('Perform system audit');
    expect(result, contains('All systems nominal'));
    expect(agent.getState('scansCompleted'), equals(1));
    expect(agent.getState('lastAuditStatus'), equals('passed'));
  });
}
```

---

## 📱 5. Embedding into an Application

### Pattern A: Android Native Host (Kotlin / Gradle)

Add `android_mobi_nooa` to your Android app's `build.gradle.kts`:

```kotlin
// In your Android ViewModel / Activity / Service:
val bridge = MobiNooaBridge(context)
bridge.initialize()

// Run any agent asynchronously in a non-killable Foreground Service
val request = mapOf(
    "action" to "runAgentLoop",
    "agentName" to "AutonomousDeviceAgent",
    "goal" to "Diagnose battery drain and alert if unplugged",
    "model" to mapOf(
        "provider" to "on_device",
        "template" to "llama3"
    ),
    "maxSteps" to 5
)

val response = bridge.sendAction(request)
val result = response["result"]
```

### Pattern B: Pure Dart CLI / Backend

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() async {
  final agent = Quickstart.createAgent(
    () => AutonomousCodingAgent(),
    model: GeminiClient(apiKey: Platform.environment['GEMINI_API_KEY']!),
  );

  final result = await agent.ellipsis<String>(
    'Find and fix the syntax error in lib/main.dart',
    maxSteps: 8,
  );
  print('Result: $result');
}
```

---

## 🧠 6. Two-Way Runtime Skills & Approved Repositories (`nooa-skills`)

Procedural skills provide deterministic execution recipes that bridge the gap between large cloud models and compact 1B–3B on-device models:

```dart
// 1. Configure SkillStore with approved file repository or memory catalog
final fs = MemoryFileSystemHarness();
final store = FileSystemSkillStore(fs, skillsDirectory: '/approved_skills');

// 2. Enhance Agent with dynamic skill matching
final enhancer = SkillPromptEnhancer(store);
final enhancedPrompt = await enhancer.enhancePrompt(
  'Base system instructions.',
  'Triage battery thermal overheating',
);

// 3. Enable Outbound Learning (Agent synthesizes newly discovered skills)
final harness = SkillHarness(store);
await harness.createSkill(
  id: 'device-thermal-saver',
  name: 'Device Thermal Throttling',
  description: 'Procedure to reduce screen brightness and stop background tasks',
  instructions: '1. Check temp\n2. Lower brightness\n3. Emit alert',
);
```

---

## 🤖 7. Model Provisioning (Cloud vs. On-Device)

`mobi-nooa` supports swappable LLM clients:

- **`OnDeviceModelClient`**: Local offline inference via `llama.cpp` (GGUF) or `LiteRT-LM` (ARM64 NEON / Hexagon NPU / Tensor EdgeTPU).
  - Templates: `PromptTemplate.llama3`, `PromptTemplate.chatMl`, `PromptTemplate.gemma`, `PromptTemplate.raw`.
- **Frontier Cloud Clients**: `GeminiClient`, `AnthropicClient`, `OpenAIClient`, `OllamaClient`.

---

## 🔍 8. Verification Commands

Run static analysis and tests before submitting pull requests:

```bash
cd mobi_nooa_core
dart analyze
dart test
```
