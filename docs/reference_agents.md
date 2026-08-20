# Built-in Reference Agents & Architecture Guide

`mobi-nooa` ships with five pre-built, production-ready reference agents implementing the 6 principles of **NVIDIA Object-Oriented Agents (NOOA)** ([arXiv:2607.20709](https://arxiv.org/abs/2607.20709)).

This guide covers:
1. **The 5 Built-in Agents** (What they are & where they fit).
2. **How Agents are Activated** (Dart API, 3-Line Quickstart, Android Service, JSON Bridge).
3. **How Models are Injected** (Frontier Cloud LLMs vs. Quantized On-Device GGUF/LiteRT).
4. **Skills & Memory Management Architecture**.

---

## 1. Reference Agents Catalog

| Agent Class | Primary Role | Core Capabilities & Tools | Key NOOA Principles |
|---|---|---|---|
| **[`AutonomousDeviceAgent`](file:///C:/Users/dband/OneDrive/Documents/Development/hermes/nooa/mobi_nooa_core/lib/src/agent/autonomous_device_agent.dart)** | On-Device Triage & System Automation | Battery, network, notification, vibration, and **procedural skill lookup & synthesis** (`searchSkills`, `loadSkill`, `learnSkill`). | Principle 1 (Class-as-Agent), Principle 5 (Explicit State), Principle 6 (Harness APIs) |
| **[`DataAnalystAgent`](file:///C:/Users/dband/OneDrive/Documents/Development/hermes/nooa/mobi_nooa_core/lib/src/agent/data_analyst_agent.dart)** | Tabular Data Science & Analytics | Dataset generation, statistical summaries, filtering, SQLite queries via **pass-by-reference handles** (`#ref_xxx`). | Principle 2 (Pass-by-Reference Heap), Principle 6 (SQLite Harness) |
| **[`AutonomousCodingAgent`](file:///C:/Users/dband/OneDrive/Documents/Development/hermes/nooa/mobi_nooa_core/lib/src/agent/autonomous_coding_agent.dart)** | Software Engineering & Bug Repair | Line-numbered file inspection (`viewFile`), exact replacement (`strReplace`), `runShell`, AST regex search (`grepCode`), and procedural coding skills. | Principle 1, Principle 3 (CodeAct), Principle 6 (Harness Tools) |
| **[`BenchAgent`](file:///C:/Users/dband/OneDrive/Documents/Development/hermes/nooa/mobi_nooa_core/lib/src/agent/bench_agent.dart)** | Benchmark-Agnostic Coding Evaluation | Official NVIDIA SWE-bench & CyberGym port; executes repository navigation, terminal execution, and verified patch application. | Principle 1, Principle 3, Principle 4 (Loop Engineering) |
| **[`GeneralMobileAgent`](file:///C:/Users/dband/OneDrive/Documents/Development/hermes/nooa/mobi_nooa_core/lib/src/agent/general_mobile_agent.dart)** | Minimal Mobile Assistant | Lightweight baseline agent equipped with hardware status queries and explicit state note-taking. | Principle 1, Principle 5 (Explicit State) |

---

## 2. Architectural Blueprint

```
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                                     Host Layer                                         │
 │   ┌───────────────────────┐   ┌───────────────────────────┐   ┌────────────────────┐   │
 │   │  MobiNooaService.kt   │   │     MobiNooaWorker.kt     │   │   Interactive CLI  │   │
 │   │ (Foreground Service)  │   │   (Background WorkMgr)    │   │ (bin/mobi_nooa.dart│   │
 │   └───────────┬───────────┘   └─────────────┬─────────────┘   └─────────┬──────────┘   │
 └───────────────┼─────────────────────────────┼───────────────────────────┼──────────────┘
                 │                             │                           │
                 ▼                             ▼                           ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                             AgentBridgeDispatcher                                      │
 │                (Transport-Agnostic JSON Execution Router in Pure Dart)                 │
 └─────────────────────────────────────────────┬──────────────────────────────────────────┘
                                               │
                        ┌──────────────────────┴──────────────────────┐
                        │                                             │
                        ▼                                             ▼
       ┌─────────────────────────────────┐           ┌─────────────────────────────────┐
       │         NooaAgent Instances      │           │         Model Providers         │
       ├─────────────────────────────────┤           ├─────────────────────────────────┤
       │ • AutonomousDeviceAgent         │           │ • OnDeviceModelClient (Local)   │
       │ • DataAnalystAgent              │◄──────────┤   - Llama 3.2 1B/3B (llama.cpp) │
       │ • AutonomousCodingAgent         │           │   - Gemma 2 2B (LiteRT-LM)      │
       │ • BenchAgent                    │           │ • GeminiClient (Gemini 1.5 Pro) │
       │ • GeneralMobileAgent            │           │ • AnthropicClient (Claude 3.5)  │
       └────────────────┬────────────────┘           │ • OpenAIClient (GPT-4o)         │
                        │                            │ • OllamaClient                  │
                        │                            └─────────────────────────────────┘
                        ▼
       ┌───────────────────────────────────────────────────────────────────────────────┐
       │                            Model-Callable Harness APIs                        │
       ├─────────────────────────┬─────────────────────────┬───────────────────────────┤
       │ DeviceHarness (Native)  │ SkillHarness (ADR 0009) │ SqliteHarness / Storage   │
       │ FileSystemHarness       │ CognitiveMemoryStore    │ McpHarness (Extensions)   │
       └─────────────────────────┴─────────────────────────┴───────────────────────────┘
```

---

## 3. How Agents are Activated

### Option A: Pure Dart 3-Line Quickstart

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() async {
  // 1. Instantiate agent and inject model
  final agent = Quickstart.createAgent(
    () => AutonomousDeviceAgent(),
    model: GeminiClient(apiKey: 'GEMINI_API_KEY'),
  );

  // 2. Execute agentic goal with dynamic ellipsis loop
  final result = await agent.ellipsis<String>(
    'Diagnose battery status and send an alert if charging is disconnected',
    maxSteps: 5,
  );

  print('Result: $result');
}
```

### Option B: Platform Bridge (Android / Kotlin / JSON RPC)

Embedders can trigger any agent without importing Dart types directly by sending a JSON request map to `AgentBridgeDispatcher`:

```kotlin
val request = mapOf(
    "action" to "runAgentLoop",
    "agentName" to "AutonomousDeviceAgent",
    "goal" to "Triage battery drain and check network status",
    "model" to mapOf(
        "provider" to "on_device",
        "template" to "llama3"
    ),
    "maxSteps" to 5
)

// Bridge dispatches through headless FlutterEngine
val response = bridge.sendAction(request)
```

---

## 4. Providing an LLM to the Agents

`mobi-nooa` treats models as swappable `ModelClient` implementations:

### 1. Local On-Device Inference (`OnDeviceModelClient`)
Quantized GGUF models running offline via `llama.cpp` or `LiteRT-LM`:
```dart
final onDeviceModel = OnDeviceModelClient(
  template: PromptTemplate.llama3, // llama3, chatMl, gemma, raw
  bridgeCallback: (action, params) async {
    // Delegated to JNI llama.cpp engine in Kotlin
    return await nativeInferenceEngine.generate(params);
  },
);
```

### 2. Frontier Cloud Providers
```dart
final gemini = GeminiClient(apiKey: '...');
final claude = AnthropicClient(apiKey: '...');
final gpt4o  = OpenAIClient(apiKey: '...');
final local  = OllamaClient(modelName: 'qwen2.5:3b');
```

---

## 5. Skills & Memory Subsystem Integration

1. **Inbound Skills (TO the Agent)**: When `AutonomousDeviceAgent` or `AutonomousCodingAgent` executes, `SkillPromptEnhancer` dynamically retrieves matched procedural recipes from `InMemorySkillStore` or `FileSystemSkillStore` and injects them into the prompt.
2. **Outbound Skills (FROM the Agent)**: When frontier models or human sessions discover a new fix, the agent invokes `learnSkill(...)` to permanently save the recipe into `/skills/*.json`.
3. **Pass-by-Reference Data Handling**: `DataAnalystAgent` passes large tabular buffers into `ObjectHeap` (`#ref_1`, `#ref_2`), allowing 1B local models to manipulate 100,000+ row datasets without context window limits.
