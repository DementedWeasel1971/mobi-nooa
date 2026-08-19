# Getting Started with mobi-nooa

Welcome to **mobi-nooa**! This guide walks you through setting up your environment and running your first autonomous mobile agent in under 5 minutes.

---

## 📋 Prerequisites

- **Dart SDK**: 3.0.0 or higher (`dart --version`)
- **Android Studio / Android SDK**: API Level 26+ (Android 8.0 Oreo or higher)
- **Kotlin**: 1.9+
- **Model API Key** (optional for live LLMs): Google Gemini, OpenAI, Anthropic, or Ollama for local LLMs. `MockModelClient` is included out-of-the-box for offline testing.

---

## ⚡ 5-Minute Quickstart

### 1. Clone and Install Dependencies

```bash
git clone https://github.com/hermes/mobi-nooa.git
cd mobi-nooa/mobi_nooa_core
dart pub get
```

### 2. Verify Your Installation

Run static analysis and the automated test suite:

```bash
dart analyze
dart test
```

You should see all unit and integration tests passing cleanly.

### 3. Run the Interactive CLI Agent

```bash
dart run bin/mobi_nooa.dart --trace
```

---

## 🧑‍💻 Writing Your First Agent in 3 Lines

Create a new file `my_first_agent.dart`:

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() async {
  // 1. Instantiate the agent with a model provider
  final agent = Quickstart.createAgent(
    () => GeneralMobileAgent(),
    model: MockModelClient(), // Or GeminiClient(apiKey: 'YOUR_GEMINI_KEY')
  );

  // 2. Execute an autonomous goal
  final response = await agent.ellipsis<String>('Audit device battery and storage status.');

  // 3. Print the result and inspected state
  print('Agent Result: $response');
  print('Agent Explicit State: ${agent.getStateSnapshot()}');
}
```

Run your agent:

```bash
dart run my_first_agent.dart
```

---

## 🧭 Next Steps

- Explore the [Progressive Tutorials Catalog](../mobi_nooa_core/example/README.md) for 10 hands-on coding examples.
- Read the [System Architecture Guide](./architecture.md) to understand the 6 NOOA principles.
- Check out the [Developer Guide](./developer_guide.md) to build custom domain-specific agents and harnesses.
