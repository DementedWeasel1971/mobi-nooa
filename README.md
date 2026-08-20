# mobi-nooa: Mobile Object-Oriented Agent Harness for Android

[![Dart CI](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev)
[![Kotlin Android](https://img.shields.io/badge/Kotlin-Android-green.svg)](https://developer.android.com/kotlin)
[![NVIDIA NOOA Compatible](https://img.shields.io/badge/NVIDIA-NOOA%20Compatible-76B900.svg)](https://github.com/NVIDIA-NeMo/labs-OO-Agents)
[![Tests Passing](https://img.shields.io/badge/Tests-38%2F38%20Passing-success.svg)](file:///c:/Users/dband/OneDrive/Documents/Development/hermes/nooa/mobi_nooa_core/test)

**`mobi-nooa`** is a high-performance mobile agentic harness designed to turn any modern Android mobile phone into an autonomous, object-oriented AI agent runtime. It faithfully implements the architecture, modules, and design principles of **NVIDIA Object-Oriented Agents (NOOA)** ([`NVIDIA-NeMo/labs-OO-Agents`](https://github.com/NVIDIA-NeMo/labs-OO-Agents), arXiv:[2607.20709](https://arxiv.org/abs/2607.20709)) using Kotlin and Dart.

---

## The 6 NOOA Principles in `mobi-nooa`

| # | NOOA Principle | Python NOOA (`labs-OO-Agents`) | `mobi-nooa` Mobile Implementation |
|---|---|---|---|
| 1 | **Typed Input/Output** | Python type annotations & docstrings | Strongly typed Dart classes, method signatures, `@Prompt`, `@Doc`, and `@Action` reflection |
| 2 | **Pass-by-Reference over Live Objects** | Object heap holding dataframes/buffers, prompt previews | Mobile `ObjectHeap` allocating handles (`#ref_xxx`), `BoundedPreviewGenerator` preventing prompt blowup |
| 3 | **Code as Action (CodeAct)** | Python sandbox execution | Sandboxed mobile execution engine (`CodeActEngine`, `AstEvaluator`) with AST security guardrails |
| 4 | **Programmable Loop Engineering** | Native control flow & loops | `AgentLoop`, `ReActStrategy`, `CodeActStrategy`, `PlanAndSolveStrategy`, `SelfReflectionStrategy` |
| 5 | **Explicit Object State** | Python class instance attributes (`self.state`) | First-class agent fields (`setState`, `getStateSnapshot`), SQLite state persistence & checkpointing |
| 6 | **Model-Callable Harness APIs** | Harness tools & OS interfaces | Android hardware bridge (`DeviceHarness`), `SqliteHarness`, `SkillHarness` (ADR 0009), FS, Network, Memory, MCP |

---

## Subsystems & Architecture

### 1. `nooa-memory`: Cognitively Grounded Long-Term Memory
- **ACT-R Activation Equation**: $A_i = B_i + W \cdot \text{Importance} + S_{\text{context}} + \epsilon$
- **Ebbinghaus Forgetting Curve**: Base-level activation $B_i = \ln \sum_{k=1}^n (t - t_k)^{-d}$ incorporating power-law practice and decay.
- **Owner-Gated Scoping**: Strict multi-tenant / multi-agent security boundaries preventing memory leakage.

### 2. `BenchAgent` & SOTA Developer Tooling
- Port of NVIDIA's compact benchmark agent that achieved SOTA results on **SWE-bench Verified (82.2%)** and **CyberGym (86.8%)**:
  - `runShell`: Terminal execution with directory tracking, timeouts, and output truncation.
  - `strReplace`: Whitespace-exact substring replacement with uniqueness validation.
  - `viewFile`: Line-sliced file inspection.
  - `grepCode` & `listSymbols`: Fast regex and multi-language AST/symbol extraction.

### 3. `nooa.storage`: State Checkpointing & SQLite
- `StateStorageManager` & `AgentCheckpoint`: Complete serialization of paused agent states, loops, and object heaps to SQLite for crash recovery and resume.

### 4. `nooa-skills`: Two-Way Procedural Knowledge (ADR 0009)
- **Inbound Skills**: Dynamic retrieval and prompt injection of structured checklists and recipes to elevate 1B–3B on-device model consistency.
- **Outbound Skills**: Model-callable `SkillHarness` enabling autonomous agents to synthesize and persist newly discovered procedures.

### 5. `nooa.strategies`: Execution Strategies
- **ReAct**: Explicit Thought -> Action -> Observation reasoning cycles.
- **CodeAct**: Direct multi-statement code generation and execution against live objects.
- **PlanAndSolve**: Two-stage task decomposition and sequential step execution.
- **SelfReflection**: Root-cause diagnosis and correction hypothesis formulation upon error.

### 6. `nooa.bench`: Evaluation Suite
- On-device benchmark runner generating SOTA metrics (pass rate, step efficiency, token usage) and JSONL reports for SWE-bench and Mobile-Bench.

---

## Repository Layout

```
nooa/
├── mobi_nooa_core/                     # Pure Dart Core Engine
│   ├── lib/
│   │   ├── mobi_nooa_core.dart         # Public Barrel Export
│   │   └── src/
│   │       ├── agent/                  # NooaAgent, BenchAgent, GeneralMobileAgent, Reflector
│   │       ├── heap/                   # ObjectHeap, ObjectReference, BoundedPreview
│   │       ├── engine/                 # CodeActEngine, SandboxedEnvironment, AstEvaluator
│   │       ├── security/               # AstGuardrails (AST validation & deny-lists)
│   │       ├── memory/                 # CognitiveMemoryStore, ActRActivation, OwnerGatedScope
│   │       ├── storage/                # AgentCheckpoint, StateStorageManager
│   │       ├── skills/                 # Skill, SkillStore, SkillHarness (nooa-skills)
│   │       ├── strategies/             # ReAct, CodeAct, PlanAndSolve, SelfReflection
│   │       ├── bench/                  # BenchmarkSuite, SweBenchSuite, MobileBenchSuite
│   │       ├── tools/                  # FileEditorTool, ShellHarness, CodeSearchTool
│   │       ├── models/                 # Gemini, OpenAI, Claude, Ollama, OnDevice models
│   │       ├── harness/                # Device, FileSystem, Network, Memory, MCP, SQLite
│   │       ├── util/                   # Quickstart, PromptBuilder
│   │       └── tracing/                # Tracer, TraceEvent, JSONL telemetry
│   ├── example/
│   │   ├── data_scientist_agent.dart   # Pass-by-reference on 5000+ row dataset
│   │   ├── mobile_assistant_agent.dart # On-device battery alerts & state management
│   │   └── run_benchmarks.dart         # SOTA Benchmark Runner (SWE-bench + MobileBench)
│   ├── bin/
│   │   └── mobi_nooa.dart              # Interactive Mobile Agent CLI
│   └── test/
│       ├── nooa_principles_test.dart   # Tests for all 6 NOOA principles
│       ├── bench_agent_test.dart       # Tests for BenchAgent & developer tools
│       ├── cognitive_memory_test.dart  # Tests for ACT-R & Ebbinghaus decay
│       ├── on_device_client_test.dart  # Tests for on-device models & bridge
│       ├── skills_test.dart            # Tests for nooa-skills subsystem
│       └── strategies_and_storage_test.dart # Tests for strategies & checkpoints
│
└── android_mobi_nooa/                  # Kotlin Android Native Layer
    ├── build.gradle.kts
    └── src/main/
        ├── AndroidManifest.xml
        └── kotlin/com/mobi/nooa/
            ├── MobiNooaService.kt      # Android Foreground Service (non-killable loops)
            ├── MobiNooaWorker.kt       # WorkManager periodic/scheduled background worker
            ├── MobiNooaBridge.kt       # Headless FlutterEngine + MethodChannel bridge
            ├── DeviceHarnessBridge.kt  # Battery, Location, Notification & Hardware bridge
            └── OnDeviceModelEngine.kt  # LiteRT / MediaPipe / llama.cpp local inference

mobi_nooa_bridge/                       # Headless Flutter "add-to-app" shim (no UI)
├── pubspec.yaml                        # Depends on flutter + mobi_nooa_core (path)
├── lib/main.dart                       # Forwards MethodChannel calls into
│                                       # AgentBridgeDispatcher.handle
└── test/bridge_handler_test.dart

app/                                    # Minimal com.android.application host module
├── build.gradle.kts                    # required by the Flutter Gradle plugin's
└── src/main/...                        # add-to-app pattern; depends on android_mobi_nooa

settings.gradle.kts, build.gradle.kts,  # Root Gradle project wiring android_mobi_nooa,
gradlew, gradle/                        # app, and the generated :flutter module together.
```

See `docs/decisions/0007-close-dart-android-bridge-gap.md` for the full
Dart↔Kotlin bridge design, and `docs/decisions/0008-on-device-llm-runtime-architecture.md`
for the on-device inference engine architecture (llama.cpp + LiteRT-LM).

---

## Quick Start

```bash
# 1. Install dependencies
cd mobi_nooa_core
dart pub get

# 2. Run static analysis and all automated tests
dart analyze
dart test

# 3. Run Benchmark Suite (SWE-bench & Mobile-Bench)
dart run example/run_benchmarks.dart

# 4. Run Interactive Agent CLI
dart run bin/mobi_nooa.dart --trace
```

### Full Android build (Kotlin + Flutter bridge + Dart core)

Requires the Flutter SDK, Android SDK (with a platform + build-tools + NDK),
and JDK 17+ installed locally.

```bash
# 1. Copy the local config template and point it at your SDK installs
cp local.properties.example local.properties
# edit local.properties: set sdk.dir and flutter.sdk

# 2. Fetch the Flutter bridge shim's dependencies
cd mobi_nooa_bridge && flutter pub get && cd ..

# 3. Build the full APK (android_mobi_nooa + mobi_nooa_bridge + mobi_nooa_core)
./gradlew :app:assembleDebug
```

---

## 3-Line Agent Quickstart

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() async {
  // Rapid scaffolding in 3 lines
  final agent = Quickstart.createAgent(
    () => GeneralMobileAgent(),
    model: GeminiClient(apiKey: 'YOUR_GEMINI_KEY'),
  );

  final result = await agent.ellipsis<String>('Audit device and report status.');
  print(result);
}
```

---

## License
Apache 2.0 / MIT
