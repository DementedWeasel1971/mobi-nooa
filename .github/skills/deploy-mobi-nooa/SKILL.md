---
name: deploy-mobi-nooa
description: 'Step-by-step instructions for AI developers to deploy mobi-nooa across Android applications, background services, on-device GGUF inference engines, standalone Dart CLIs, and cloud LLM providers.'
---

# Deploy mobi-nooa (AI Developer Deployment Guide)

Use this skill when deploying `mobi-nooa` into Android mobile applications, running background foreground services, provisioning quantized local LLM weights, configuring cloud model providers (DeepSeek, Gemini, OpenAI, Claude), or running the evaluation benchmark runner.

---

## 📱 1. Android Application Deployment

`mobi-nooa` runs inside Android applications through a headless Flutter engine embedding (`add-to-app`) that connects Kotlin native components to `mobi_nooa_core` via `AgentBridgeDispatcher`.

### Architecture Seam
```
[Android Native Host App]
       │
       ▼ (calls)
[android_mobi_nooa (Kotlin Library)]
  - MobiNooaService.kt (Foreground Service, non-killable loops)
  - MobiNooaWorker.kt (WorkManager periodic/scheduled background worker)
  - MobiNooaBridge.kt (Headless FlutterEngine + MethodChannel)
  - DeviceHarnessBridge.kt (Hardware telemetry, battery, notifications)
       │
       ▼ (MethodChannel "com.mobi.nooa/agent_bridge")
[mobi_nooa_bridge (Headless Flutter Shim)]
  - lib/main.dart (Forwards to AgentBridgeDispatcher.handle)
       │
       ▼ (Pure Dart Dispatcher)
[mobi_nooa_core (Dart Engine)]
  - AgentLoop, ObjectHeap, AstGuardrails, PermissionManager, Plugins, Sessions
```

### Build & Package Steps

1. **Configure SDK paths**:
   ```powershell
   # Copy configuration template
   cp local.properties.example local.properties
   
   # Ensure sdk.dir and flutter.sdk are set in local.properties:
   # sdk.dir=C:\\Users\\<user>\\AppData\\Local\\Android\\Sdk
   # flutter.sdk=C:\\src\\flutter
   ```

2. **Fetch Flutter bridge dependencies**:
   ```powershell
   cd mobi_nooa_bridge
   flutter pub get
   cd ..
   ```

3. **Build Android Debug APK**:
   ```powershell
   ./gradlew :app:assembleDebug
   ```

4. **Install APK to Connected Device / Emulator via ADB**:
   ```powershell
   adb install -r app/build/outputs/apk/debug/app-debug.apk
   ```

### Triggering Agent Runs from Kotlin

```kotlin
import com.mobi.nooa.MobiNooaBridge
import kotlinx.coroutines.launch

// Inside Android Activity, Service, or ViewModel
val bridge = MobiNooaBridge.getInstance(context)

lifecycleScope.launch {
    val response = bridge.runAgentLoop(
        agentName = "AutonomousDeviceAgent",
        goal = "Triage battery health and report status",
        modelConfig = mapOf(
            "provider" to "deepseek",
            "apiKey" to "sk-...",
            "modelName" to "deepseek-reasoner"
        ),
        maxSteps = 5
    )
    
    val result = response["result"] as? String
    val state = response["state"] as? Map<String, Any>
    android.util.Log.d("MobiNooa", "Agent finished: $result, state: $state")
}
```

---

## ⚡ 2. Local On-Device Inference Setup (GGUF / LiteRT-LM)

For 100% offline, privacy-first mobile execution:

1. **Model Weights Selection**:
   - Recommended: `Llama-3.2-1B-Instruct-Q4_K_M.gguf` (~700MB) or `Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf` (~980MB) for lightweight devices.
   - For high-end devices (Snapdragon 8 Gen 3/4, 12GB+ RAM): `Llama-3.3-8B-Instruct-Q4_K_M.gguf` or `DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf`.

2. **Prompt Template Selection**:
   Configure the matching prompt template in `OnDeviceModelClient`:
   ```dart
   final onDeviceClient = OnDeviceModelClient(
     modelName: 'llama-3.2-1b-local',
     template: PromptTemplate.llama3, // Or PromptTemplate.chatMl / PromptTemplate.gemma
   );
   ```

3. **Resource Governor Optimization**:
   Always attach `DeviceResourceGovernor` when running on-device weights to automatically throttle concurrency and cooling delays under thermal load:
   ```dart
   final governor = DeviceResourceGovernor();
   final budget = await governor.assessBudget(harness: context.harness);
   ```

---

## ☁️ 3. Cloud LLM Providers Configuration

`mobi-nooa` includes production clients for major LLM providers:

```dart
// 1. DeepSeek (DeepSeek-V3 and DeepSeek-R1 with reasoning stream)
final deepseek = DeepSeekClient(
  apiKey: Platform.environment['DEEPSEEK_API_KEY']!,
  modelName: 'deepseek-reasoner', // Or 'deepseek-chat'
);

// 2. Google Gemini 1.5 Pro / Flash
final gemini = GeminiClient(
  apiKey: Platform.environment['GEMINI_API_KEY']!,
  modelName: 'gemini-1.5-flash',
);

// 3. OpenAI GPT-4o
final openai = OpenAIClient(
  apiKey: Platform.environment['OPENAI_API_KEY']!,
  modelName: 'gpt-4o',
);

// 4. Anthropic Claude 3.5 Sonnet
final anthropic = AnthropicClient(
  apiKey: Platform.environment['ANTHROPIC_API_KEY']!,
  modelName: 'claude-3-5-sonnet-20241022',
);

// 5. Local Ollama Endpoint
final ollama = OllamaClient(
  modelName: 'deepseek-r1:1.5b',
  baseUrl: 'http://10.0.2.2:11434', // Android emulator localhost
);
```

---

## 🖥️ 4. Standalone CLI & Daemon Deployment

Run interactive agent sessions from command line or server:

```powershell
cd mobi_nooa_core

# 1. Run Interactive CLI with tracing
dart run bin/mobi_nooa.dart --trace

# 2. Run with DeepSeek reasoning
dart run bin/mobi_nooa.dart --model deepseek --api-key $env:DEEPSEEK_API_KEY
```

---

## 📊 5. Benchmark Suite Execution

Verify agent performance on standard evaluation suites (SWE-bench Verified & Mobile-Bench):

```powershell
cd mobi_nooa_core

# Run comprehensive benchmark suite
dart run example/run_benchmarks.dart
```

---

## 🧪 6. Automated 4-Tier Testing & Verification Checklist

Before releasing or deploying any new agent, harness, or strategy, execute the full test hierarchy:

```powershell
# Tier 1: Pure Dart Core Unit & Permutation Tests (120+ tests; currently 121)
cd mobi_nooa_core
dart analyze
dart test --exclude-tags live

# Tier 2: Headless Flutter Bridge MethodChannel Tests
cd ../mobi_nooa_bridge
flutter analyze
flutter test

# Tier 3: Android Native Kotlin Architecture Tests
cd ..
.\gradlew.bat :android_mobi_nooa:testDebugUnitTest

# Tier 4: Live On-Device Integration & UI Verification (connected emulator / physical device)
.\gradlew.bat :android_mobi_nooa:connectedDebugAndroidTest
```

---

## 🛡️ Production Safety & Security Invariants

When deploying into production:
1. **Tiered Permission Policies**: Enable `PermissionPolicy.defaultMobile()` or register an interactive `ApprovalCallback` on `PermissionManager` to prevent unauthorized file writes or shell executions.
2. **AST Guardrails**: Ensure `AstGuardrails.validate` remains active before any CodeAct execution.
3. **Owner-Gated Cognitive Memory**: Ensure multi-agent memory reads/writes are wrapped in `OwnerGatedMemoryScope`.
4. **Session Event Logs**: Attach `SessionEventLog` to persist chronological audit events to SQLite for compliance and recovery.
