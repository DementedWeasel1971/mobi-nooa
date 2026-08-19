# mobi-nooa: Mobile Object-Oriented Agent Harness for Android

[![Dart CI](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![Kotlin Android](https://img.shields.io/badge/Kotlin-Android-green.svg)](https://developer.android.com/kotlin)
[![NVIDIA NOOA Compatible](https://img.shields.io/badge/NVIDIA-NOOA%20Compatible-76B900.svg)](https://github.com/NVIDIA-NeMo/labs-OO-Agents)

**`mobi-nooa`** is a mobile agentic harness designed to turn any modern Android mobile phone into an autonomous, object-oriented AI agent runtime. It faithfully implements the architecture and design principles of **NVIDIA Object-Oriented Agents (NOOA)** ([`NVIDIA-NeMo/labs-OO-Agents`](https://github.com/NVIDIA-NeMo/labs-OO-Agents), arXiv:[2607.20709](https://arxiv.org/abs/2607.20709)) using Kotlin and Dart.

---

## The 6 NOOA Principles in `mobi-nooa`

| # | NOOA Principle | Python NOOA (`labs-OO-Agents`) | `mobi-nooa` Mobile Implementation |
|---|---|---|---|
| 1 | **Typed Input/Output** | Python type annotations & docstrings | Strongly typed Dart classes, method signatures, `@Prompt`, `@Doc`, and `@Action` reflection |
| 2 | **Pass-by-Reference over Live Objects** | Object heap holding dataframes/buffers, prompt previews | Mobile `ObjectHeap` allocating handles (`#ref_xxx`), `BoundedPreviewGenerator` preventing prompt blowup |
| 3 | **Code as Action (CodeAct)** | Python sandbox execution | Sandboxed mobile execution engine (`CodeActEngine`, `AstEvaluator`) with live heap bindings |
| 4 | **Programmable Loop Engineering** | Native control flow & loops | `AgentLoop`, `StepExecution`, configurable retry/termination policies, subagent spawning |
| 5 | **Explicit Object State** | Python class instance attributes (`self.state`) | First-class agent fields (`setState`, `getStateSnapshot`) with reactive streams for mobile UI |
| 6 | **Model-Callable Harness APIs** | Harness tools & OS interfaces | Android hardware bridge (`DeviceHarness`), SQLite/Vector memory (`MemoryHarness`), Sandboxed FS, Network, & MCP |

---

## Repository Structure

```
nooa/
├── mobi_nooa_core/                     # Pure Dart Core Engine
│   ├── lib/
│   │   ├── mobi_nooa_core.dart         # Public Barrel Export
│   │   └── src/
│   │       ├── agent/                  # NooaAgent, Reflector, Annotations, Context
│   │       ├── heap/                   # ObjectHeap, ObjectReference, BoundedPreview
│   │       ├── engine/                 # CodeActEngine, SandboxedEnvironment, AstEvaluator
│   │       ├── loop/                   # AgentLoop, LoopConfig, StepEvent
│   │       ├── models/                 # Gemini, OpenAI, Claude, Ollama, OnDevice models
│   │       ├── harness/                # Device, FileSystem, Network, Memory, MCP
│   │       └── tracing/                # Tracer, TraceEvent, JSONL telemetry
│   ├── example/
│   │   ├── data_scientist_agent.dart   # Pass-by-reference on 5000+ row dataset
│   │   └── mobile_assistant_agent.dart # On-device battery alerts & state management
│   ├── bin/
│   │   └── mobi_nooa.dart              # Interactive Mobile Agent CLI
│   └── test/
│       └── nooa_principles_test.dart   # Automated test suite for all 6 principles
│
└── android_mobi_nooa/                  # Kotlin Android Native Layer
    ├── build.gradle.kts
    └── src/main/
        ├── AndroidManifest.xml
        └── kotlin/com/mobi/nooa/
            ├── MobiNooaService.kt      # Android Foreground Service (non-killable loops)
            ├── MobiNooaWorker.kt       # WorkManager periodic/scheduled background worker
            ├── DeviceHarnessBridge.kt  # Battery, Location, Notification & Hardware bridge
            └── OnDeviceModelEngine.kt  # LiteRT / MediaPipe / llama.cpp local inference
```

---

## Quick Start

### 1. Prerequisites
- Dart SDK `>= 3.0.0`
- Android SDK (API level 26+ for native Android build)

### 2. Running Automated Verification
```bash
cd mobi_nooa_core
dart pub get
dart analyze
dart test
```

### 3. Running Reference Agents
```bash
# Run the Data Science Agent (demonstrating Pass-by-Reference on live datasets)
dart run example/data_scientist_agent.dart

# Run the Mobile Assistant Agent (demonstrating device harness & state tracking)
dart run example/mobile_assistant_agent.dart

# Run the Interactive CLI with JSONL Tracing
dart run bin/mobi_nooa.dart --trace
```

---

## Defining a Mobile OO-Agent

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class BatteryMonitorAgent extends NooaAgent {
  BatteryMonitorAgent()
      : super(
          name: 'BatteryMonitorAgent',
          role: 'Power Management Agent',
          description: 'Monitors Android battery status and manages low power alerts.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'checkBattery',
      description: 'Reads battery percentage from the device harness.',
      returnType: 'double',
      invoker: (args) async {
        final status = await context.harness.device.getStatus();
        setState('lastBatteryLevel', status.batteryLevel);
        return status.batteryLevel;
      },
    );
  }
}

void main() async {
  final heap = ObjectHeap();
  final harness = HarnessApi();
  final model = GeminiClient(apiKey: 'YOUR_GEMINI_KEY');

  final agent = BatteryMonitorAgent();
  agent.attachContext(AgentContext(
    heap: heap,
    model: model,
    harness: harness,
    tracer: Tracer('BatteryAgentTracer'),
  ));

  // The NOOA Ellipsis pattern (...) dynamically fulfilled by LLM loop
  final result = await agent.ellipsis<String>('Check battery and notify me if under 20%.');
  print(result);
}
```

---

## License
Apache 2.0 / MIT
