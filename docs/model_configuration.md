# Model Configuration Guide

`mobi-nooa` supports a hybrid inference architecture: high-capacity cloud foundation models (via **NVIDIA NIM**, Google Gemini, OpenAI, Anthropic Claude) and low-latency, private **On-Device models** (via `llama.cpp` GGUF and `LiteRT-LM`).

---

## 🟢 1. NVIDIA NIM & AI Foundation Models

NVIDIA provides high-throughput, enterprise-grade NIM microservices with **1,000 free evaluation credits** for developers at [build.nvidia.com](https://build.nvidia.com).

### Step 1: Obtain a Free NVIDIA NIM API Key
1. Visit [build.nvidia.com](https://build.nvidia.com) and create a free developer account.
2. Select any model (e.g. `meta/llama-3.3-70b-instruct`) and click **"Get API Key"**.
3. Generate a personal API key (starts with `nvapi-...`).

### Step 2: Configure Environment Settings
Create or update your `.env` file in the project root:

```env
NVIDIA_API_KEY=nvapi-your-key-here
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
NVIDIA_MODEL=meta/llama-3.3-70b-instruct
```

> [!NOTE]
> `.env` is automatically ignored by `.gitignore` to prevent leaking API keys into public repositories. Use `.env.example` as a template for other team members.

---

## 🔍 2. How to Lookup Available Free / NIM Models

NVIDIA NIM hosts hundreds of state-of-the-art open-weights models accessible via your API key.

### A. Dynamic Model Lookup via CLI
You can search and inspect all available models directly from the command line:

```bash
# List all models available on your NVIDIA NIM endpoint
dart run bin/mobi_nooa.dart --list-models

# Filter models by keyword (e.g. llama, qwen, mistral, deepseek)
dart run bin/mobi_nooa.dart -l -f llama
dart run bin/mobi_nooa.dart -l -f qwen
dart run bin/mobi_nooa.dart -l -f nemotron
```

### B. Programmatic Model Lookup in Dart
```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() async {
  // Query all live models from the NIM endpoint
  final models = await NvidiaClient.fetchModels(
    apiKey: 'nvapi-...',
  );

  print('Total models available: ${models.length}');
  for (final modelId in models.where((m) => m.contains('instruct'))) {
    print(' • $modelId');
  }
}
```

### C. Curated Catalog of Recommended Models for `mobi-nooa`

| Model Identifier | Parameter Size | Primary Agent Use Case | Tool Calling |
|---|---|---|:---:|
| `meta/llama-3.3-70b-instruct` *(Default)* | 70B | General reasoning, system triage, autonomous loops | **Yes** |
| `nvidia/llama-3.1-nemotron-70b-instruct` | 70B | Complex planning, multi-step CodeAct synthesis | **Yes** |
| `qwen/qwen2.5-coder-32b-instruct` | 32B | High-accuracy software engineering (`AutonomousCodingAgent`) | **Yes** |
| `mistralai/mistral-large-2-instruct` | 123B | Complex mathematical & data analytics reasoning | **Yes** |
| `deepseek-ai/deepseek-r1` | 671B (MoE) | Deep chain-of-thought & step-by-step reflection | Text |
| `meta/llama-3.2-3b-instruct` | 3B | Ultra-fast cloud baseline mirroring mobile SLMs | **Yes** |
| `z-ai/glm-5.2` | Multilingual | Multilingual device assistant tasks | **Yes** |

---

## 🧑‍💻 3. Instantiating Models in Dart & Android

### Pure Dart Quickstart with `NvidiaClient`
```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() async {
  final client = NvidiaClient(
    apiKey: 'nvapi-...',
    modelName: 'meta/llama-3.3-70b-instruct',
  );

  final agent = Quickstart.createAgent(
    () => AutonomousDeviceAgent(),
    model: client,
  );

  final result = await agent.ellipsis<String>(
    'Audit device telemetry and summarize status.',
    maxSteps: 5,
  );
  print(result);
}
```

### Android Host App Integration (`AgentBridgeDispatcher`)
In native Android (Kotlin), pass the model configuration via the bridge:

```kotlin
val modelConfig = mapOf(
    "provider" to "nvidia",
    "apiKey" to "nvapi-...",
    "modelName" to "meta/llama-3.3-70b-instruct"
)

bridge.runAgent(
    agentName = "AutonomousDeviceAgent",
    prompt = "Check battery and storage health",
    model = modelConfig
)
```

---

## 📱 4. Other Supported Model Providers

### Google Gemini (`GeminiClient`)
```dart
final gemini = GeminiClient(
  apiKey: 'AIzaSy...',
  modelName: 'gemini-1.5-flash',
);
```

### OpenAI (`OpenAIClient`)
```dart
final openai = OpenAIClient(
  apiKey: 'sk-...',
  modelName: 'gpt-4o',
);
```

### Anthropic Claude (`AnthropicClient`)
```dart
final claude = AnthropicClient(
  apiKey: 'sk-ant-...',
  modelName: 'claude-3-5-sonnet-20241022',
);
```

### Local Workstation Ollama (`OllamaClient`)
```dart
final ollama = OllamaClient(
  baseUrl: 'http://localhost:11434',
  modelName: 'llama3.2:3b',
);
```

### On-Device Inference (`OnDeviceModelClient` / GGUF & LiteRT)
```dart
final onDevice = OnDeviceModelClient(
  template: PromptTemplate.llama3,
);
```
