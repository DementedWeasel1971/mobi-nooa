# Official Flutter AI Development Guidelines & Invariants

This configuration adopts the official Flutter AI development standards (from `github.com/flutter/flutter` and `docs.flutter.dev/ai`) to guide AI coding assistants in building high-performance, robust, and accessible Flutter & Dart applications.

---

## 🎯 1. Modern Dart 3.x Idioms & Language Standards

- **Pattern Matching & Switch Expressions**:
  - Prefer switch expressions over nested `if-else` chains when mapping states or return values.
  - Use destructuring and pattern matching on records, tuples, and object patterns:
    ```dart
    final (state, value) = record;
    return switch (status) {
      DeviceStatus.nominal => 'Running optimal',
      DeviceStatus.warning => 'Thermal throttling active',
      DeviceStatus.critical => 'Eco-mode enforced',
    };
    ```
- **Sealed Class Hierarchies**:
  - Model domain states and events with `sealed class` hierarchies to ensure compile-time exhaustiveness in switch expressions:
    ```dart
    sealed class AgentExecutionState {}
    class AgentIdle extends AgentExecutionState {}
    class AgentRunning extends AgentExecutionState { final int step; AgentRunning(this.step); }
    class AgentComplete extends AgentExecutionState { final dynamic result; AgentComplete(this.result); }
    ```
- **Constructor & Class Definitions**:
  - Use concise constructor parameters and `const` constructors whenever possible.
  - Use named arguments with `required` for public APIs with more than 2 parameters.

---

## 🏗️ 2. Strict Architectural Layering

All Flutter and Dart code must respect clear separation of concerns across three distinct layers:

```
┌────────────────────────────────────────────────────────┐
│ 1. UI Layer (Presentation / Headless Bridge)           │
│    - Headless MethodChannel Dispatcher (mobi_nooa_bridge)
│    - Android ViewModels / Composables (android_mobi_nooa)
├────────────────────────────────────────────────────────┤
│ 2. Domain & Logic Layer                                │
│    - NooaAgent, AgentLoop, SubagentOrchestrator        │
│    - PlanModeManager, ExecutionStrategy, Reflector     │
├────────────────────────────────────────────────────────┤
│ 3. Data & Harness Layer                                │
│    - ObjectHeap, ModelClient, MemoryFileSystemHarness  │
│    - DeviceHarness, SqliteHarness, SessionEventLog     │
└────────────────────────────────────────────────────────┘
```

- **UI Layer**: Handles view rendering, user input, and MethodChannel communication. Zero business or model-calling logic inside widgets.
- **Domain Layer**: Pure Dart agent core. Orchestrates agent loops, state transitions (`getState`/`setState`), and planning.
- **Data & Harness Layer**: Encapsulates external devices, LLMs, SQLite persistence, and filesystem operations.

---

## ⚡ 3. UI Thread Safety & Performance Invariants

- **Keep Main Thread Unblocked**:
  - Never execute heavy synchronous operations (large JSON parsing, regex scanning across hundreds of files, heavy cryptographic hashing) on the main/UI thread.
  - Offload heavy tasks to Dart `Isolate.run()` or background workers (`MobiNooaWorker.kt` / `WorkManager`).
- **Memory Management & Disposal**:
  - Always cancel `StreamSubscription` instances, close `StreamController`s, and cancel `Timer`s in `dispose()`.
  - Avoid capturing large object blobs in closures — store large objects in `ObjectHeap` and pass handles (`#ref_xxx`).
- **Widget Tree Rebuild Optimization**:
  - Use `const` widgets at leaf nodes to prune redundant subtree rebuilds.
  - Break complex widgets into smaller, focused sub-widgets with localized state.

---

## 🛡️ 4. Accessibility (a11y) & Usability Standards

- **Semantic Labeling**: Wrap interactive custom widgets in `Semantics` widgets with clear, descriptive `label`, `hint`, and `button: true`.
- **Minimum Tap Targets**: Ensure all clickable elements meet the standard minimum touch target size of **48x48 logical pixels** (`minSize: Size(48, 48)`).
- **Color Contrast**: Enforce WCAG 2.1 AA contrast ratios (minimum 4.5:1 for normal text, 3:1 for large text and UI components).
- **Dynamic Type & Scalable Text**: Always respect system font scaling and avoid fixed pixel heights on text containers that cause text clipping.

---

## 🧪 5. Testing & Real-Time MCP Iteration

- **Live Iteration with MCP Tools**:
  - Proactively connect to running apps via `dart-mcp-server` (`dtd`, `hot_reload`, `hot_restart`, `analyze_files`, `get_runtime_errors`).
  - After modifying Dart/Flutter source files, trigger `hot_reload` immediately to verify changes without rebuilding the full binary.
- **Automated Verification**:
  - Pure in-memory unit tests (`dart test`) for core algorithms, fallback cascades, and parsers.
  - Platform channel unit tests (`flutter test`) for MethodChannel bridges.
  - On-device instrumentation tests via ADB for real hardware verification.
