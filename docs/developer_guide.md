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

## 🧪 3. Test-Driven Development (TDD) Workflow

In agentic AI engineering, testing non-deterministic LLMs is a common bottleneck. `mobi-nooa` is engineered from the ground up to enable a strict **Test-Driven Development (TDD)** lifecycle (**Red → Green → Refactor**):

### Step 1 (RED): Write the Deterministic Agent Test First
Before writing a new agent or harness, write a failing unit test in `mobi_nooa_core/test/` using `MockModelClient`. This allows you to simulate exact multi-step tool calls, thoughts, and assertions without connecting to real LLMs or spending API credits:

```dart
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('SystemAuditorAgent (TDD)', () {
    test('audits device health and records passed state', () async {
      // 1. Arrange deterministic mock LLM trajectory
      final mockModel = MockModelClient();
      mockModel.queueToolCall(
        toolName: 'runAudit',
        arguments: {'includeNetwork': true},
        thought: 'Checking system battery and connectivity.',
      );
      mockModel.queueText('System health check complete: All metrics nominal.');

      // 2. Instantiate agent with mock client
      final agent = Quickstart.createAgent(
        () => SystemAuditorAgent(),
        model: mockModel,
      );

      // 3. Act: Run agentic loop
      final result = await agent.ellipsis<String>('Perform system audit');

      // 4. Assert: Verify result and explicit state mutations
      expect(result, contains('All metrics nominal'));
      expect(agent.getState('scansCompleted'), equals(1));
      expect(agent.getState('lastAuditStatus'), equals('passed'));
    });
  });
}
```

### Step 2 (GREEN): Implement Minimal Logic
Implement the `NooaAgent` subclass, register actions, and wire lazy tools until `dart test` passes.

### Step 3 (REFACTOR): Security Hardening & Analysis
- Ensure CodeAct snippets pass `AstGuardrails.validate`.
- Wrap large return payloads with `ObjectHeap.maybeWrap`.
- Verify `dart analyze` passes with zero errors and zero warnings.

---

## 📱 4. Kotlin Android TDD & Architecture

When building Android apps on top of `android_mobi_nooa`, use the clean architecture layers (`AgentRepository` and `AgentViewModel`) tested with `kotlinx-coroutines-test`:

### Kotlin TDD Test Pattern
```kotlin
@Test
fun `agentViewModel executes goal and updates state to Success`() = runTest {
    val repository = FakeAgentRepository()
    val viewModel = AgentViewModel(repository)

    viewModel.executeGoal(
        agentName = "AutonomousDeviceAgent",
        goal = "Triage battery drain",
        modelConfig = ModelConfig.OnDevice(template = "llama3")
    )

    // Verify reactive StateFlow transitions
    val finalState = viewModel.agentState.first { it is AgentState.Success }
    assertThat((finalState as AgentState.Success).result.output).contains("Battery triage complete")
}
```

---

## 📱 5. Embedding into an Application

### Pattern A: Android Native Host (Jetpack Compose / ViewModel)

In your Android application, inject `AgentRepository` into your UI / `ViewModel`:

```kotlin
class TriageActivity : ComponentActivity() {
    private val agentViewModel: AgentViewModel by viewModels {
        AgentViewModelFactory(DefaultAgentRepository(MobiNooaBridge(this)))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val state by agentViewModel.agentState.collectAsState()

            when (val s = state) {
                is AgentState.Idle -> Button(onClick = {
                    agentViewModel.executeGoal(
                        agentName = "AutonomousDeviceAgent",
                        goal = "Diagnose battery drain and alert if unplugged",
                        modelConfig = ModelConfig.OnDevice(template = "llama3")
                    )
                }) { Text("Run Device Agent") }
                is AgentState.Running -> CircularProgressIndicator()
                is AgentState.Success -> Text("Result: ${s.result.output}")
                is AgentState.Failed -> Text("Error: ${s.error}", color = Color.Red)
            }
        }
    }
}
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

- **DeepSeek AI (`DeepSeekClient`)**: Full support for DeepSeek-R1 (`deepseek-reasoner`) reasoning streams (`reasoning_content` and `<think>` tags) and DeepSeek-V3 (`deepseek-chat`) with prompt cache telemetry (`prompt_cache_hit_tokens`).
- **`OnDeviceModelClient`**: Local offline inference via `llama.cpp` (GGUF) or `LiteRT-LM` (ARM64 NEON / Hexagon NPU / Tensor EdgeTPU).
  - Templates: `PromptTemplate.llama3`, `PromptTemplate.chatMl`, `PromptTemplate.gemma`, `PromptTemplate.raw`.
- **Frontier Cloud Clients**: `GeminiClient`, `AnthropicClient`, `OpenAIClient`, `OllamaClient`, `NvidiaClient`.

---

## 🔌 8. Building Custom Plugins (`nooa-plugins`, ADR 0011)

Extend agent capabilities dynamically without modifying core classes (DeepSeek Harness "Everything is a plugin" design):

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class CustomToolsPlugin extends AgentPlugin {
  CustomToolsPlugin()
      : super(
          name: 'custom_tools',
          version: '1.0.0',
          description: 'Dynamic tools and step logging middleware',
        );

  @override
  List<ActionMetadata> get providedActions => [
        ActionMetadata(
          name: 'calculateRiskScore',
          description: 'Calculates security risk score based on telemetry',
          parameters: const [
            ToolParameter(name: 'batteryLevel', type: 'integer', description: 'Battery percentage'),
          ],
          invoker: (args) async => ((args['batteryLevel'] as int) < 20) ? 'HIGH' : 'LOW',
        ),
      ];

  @override
  Future<void> onAfterStep(int stepIndex, ModelResponse response) async {
    print('Step $stepIndex finished with ${response.usage.totalTokens} tokens.');
  }
}
```

---

## 🛡️ 9. Enforcing Tiered Permissions (`nooa-security`, ADR 0011)

Decouple permission policies from tool implementations and prompt users before dangerous actions:

```dart
final permissionManager = PermissionManager(
  policy: PermissionPolicy.defaultMobile(),
  approvalHandler: (request) async {
    // Interactively prompt user on Android UI
    print('Prompting user for: ${request.actionName} (${request.arguments})');
    return true; // Approved
  },
);

final agent = Quickstart.createAgent(
  () => AutonomousCodingAgent(),
  permissionManager: permissionManager,
);
```

---

## 📜 10. Append-Only Session Event Logging & Time-Travel Forking (ADR 0011)

Capture immutable session audit trails and explore speculative branches:

```dart
final sessionLog = SessionEventLog(sessionId: 'audit_session_01');
final agent = Quickstart.createAgent(
  () => AutonomousDeviceAgent(),
  sessionLog: sessionLog,
);

await agent.ellipsis<String>('Audit network security');

// Reconstruct agent state at step 1 (Time-Travel)
final step1Snapshot = sessionLog.replay(1);

// Fork session into a new independent branch
final forkedLog = sessionLog.fork(newSessionId: 'speculative_branch', fromStepIndex: 1);
```

---

## 🚀 11. Deployment Workflows

- **Android Mobile App**: Build and install via `./gradlew :app:assembleDebug` and `adb install`. See `.github/skills/deploy-mobi-nooa/SKILL.md`.
- **Standalone CLI**: Run interactive agent loops via `dart run bin/mobi_nooa.dart --trace`.
- **Evaluation Suite**: Run SOTA benchmarks via `dart run example/run_benchmarks.dart`.

---

## 🔍 12. Verification Commands

Run static analysis and tests before submitting pull requests:

```bash
cd mobi_nooa_core
dart analyze
dart test --exclude-tags live
```

