---
name: flutter-ai-best-practices
description: 'Official Flutter AI Developer Guidelines and best practices from github.com/flutter/flutter and docs.flutter.dev/ai covering Dart 3 idioms, layered architecture, MCP live debugging, memory leak prevention, accessibility, and thread safety.'
---

# Flutter AI Developer Best Practices & Invariants (Official Standard)

Use this skill when developing, refactoring, or reviewing Dart and Flutter code to align with the official standards established by the Flutter team (`docs.flutter.dev/ai` and `flutter/agent-plugins`).

---

## 🎯 1. Modern Dart 3.x Development Patterns

### Pattern Matching & Switch Expressions
Always replace verbose legacy conditional ladders with modern Dart 3 pattern matching and exhaustive switch expressions:

```dart
// Preferred Dart 3 pattern matching:
String formatAgentState(AgentExecutionState state) => switch (state) {
  AgentIdle() => 'Agent is ready',
  AgentRunning(:final step, :final goal) => 'Executing step $step for goal "$goal"',
  AgentComplete(:final result) => 'Finished: $result',
  AgentError(:final message) => 'Failed: $message',
};
```

### Sealed Class Domain Modeling
Define domain events and states as sealed class hierarchies to guarantee compile-time exhaustiveness:

```dart
sealed class ModelFallbackEvent {}
class FallbackTriggered extends ModelFallbackEvent {
  final String fromProvider;
  final String toProvider;
  final String reason;
  FallbackTriggered({required this.fromProvider, required this.toProvider, required this.reason});
}
class FallbackRecovered extends ModelFallbackEvent {
  final String provider;
  FallbackRecovered(this.provider);
}
```

---

## ⚡ 2. Memory Safety & Thread Performance

1. **Keep the UI Thread Responsive**:
   - Long-running compute tasks (e.g. AST parsing, large JSON string transformations) must run inside `Isolate.run()` or Kotlin background workers.
2. **Proper Resource Disposal**:
   - Always cancel `StreamSubscription` instances and call `dispose()` on controllers/notifiers:
   ```dart
   @override
   void dispose() {
     _subscription?.cancel();
     _controller.close();
     super.dispose();
   }
   ```
3. **Pass-by-Reference in Agent Contexts (NOOA Principle 2)**:
   - For large payloads (>1KB) returned by tools, wrap them via `ObjectHeap.maybeWrap(payload)` to avoid bloating LLM prompt context and incurring high memory churn.

---

## ♿ 3. Accessibility (a11y) & Design System Compliance

When generating or editing UI widgets and views:
1. **Semantic Annotations**: Provide descriptive labels for icon buttons and interactive controls (`Semantics(label: "...", button: true, child: ...)`).
2. **Touch Targets**: Minimum 48x48 logical pixels for all interactive surfaces.
3. **Contrast Compliance**: Ensure text and key UI borders meet WCAG AA contrast (minimum 4.5:1 ratio).
4. **Scalable Typography**: Avoid hard-coding container heights that clip enlarged text under system accessibility font scaling.

---

## 🛠️ 4. MCP Live Iteration & Debugging Workflow

When paired with modern AI development tools and `dart-mcp-server`:
1. **Analyze Static Issues**: Run `analyze_files` or `dart analyze` to catch type or lint warnings before pushing code.
2. **Live Inspection**: Utilize `dtd` (Dart Tooling Daemon) and `widget_inspector` to evaluate running application state.
3. **Hot Reload Changes**: Trigger `hot_reload` immediately after editing Dart files to verify UI and logic updates instantly.
4. **Runtime Stack Trace Inspection**: If an exception occurs, fetch the active stack trace using `get_runtime_errors`, locate the offending line, and apply an immediate fix.

---

## 🧪 5. Verification Checklist

Before finalizing any Flutter/Dart task, run the full verification sequence:

```powershell
# 1. Static Analysis (Zero warnings/errors required)
dart analyze
flutter analyze

# 2. Automated Test Suites
dart test --exclude-tags live
flutter test

# 3. Android Kotlin Architecture Tests
./gradlew :android_mobi_nooa:testDebugUnitTest
```
