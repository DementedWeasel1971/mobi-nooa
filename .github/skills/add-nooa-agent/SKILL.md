---
name: add-nooa-agent
description: 'Create a new object-oriented agent (NooaAgent subclass) in mobi_nooa_core following NOOA principles 1, 2, 4, 5, and 6, with explicit state, typed actions, lazy tool wiring, and pass-by-reference object heap handling.'
---

# Add a NOOA Agent

Use this skill when asked to create a new agent class in `mobi_nooa_core` (or a reference agent under `example/`) to perform domain-specific, autonomous tasks on mobile devices (e.g. data science, coding, system automation, multi-agent orchestration).

Agents in `mobi-nooa` implement the core philosophy of **NVIDIA Object-Oriented Agents (NOOA)**:
- **Class-as-agent (Principle 1)**: The class definition encapsulates the agent; docstrings, names, roles, and type annotations serve as prompts and tool contracts.
- **Pass-by-reference (Principle 2)**: Large or complex return values from tools are placed in `ObjectHeap` (`#ref_xxx`) rather than inlined in the prompt context.
- **Programmable loops (Principle 4)**: Dynamic actions trigger `ellipsis(...)` to run configurable LLM loops with telemetry.
- **Explicit state (Principle 5)**: State is managed explicitly via `setState`/`getState`/`getStateSnapshot`, not hidden in private instance fields.
- **Model-callable harness APIs (Principle 6)**: System capabilities are invoked through `context.harness.*`.

---

## Reference implementations (read before writing code)

- `mobi_nooa_core/lib/src/agent/nooa_agent.dart` — base class and core contracts
- `mobi_nooa_core/lib/src/agent/general_mobile_agent.dart` — minimal general-purpose mobile agent
- `mobi_nooa_core/lib/src/agent/bench_agent.dart` — software-engineering coding agent with tool integration
- `mobi_nooa_core/example/data_scientist_agent.dart` — agent demonstrating pass-by-reference on large datasets

---

## Pattern to follow

### 1. File placement
- Public library agents: `mobi_nooa_core/lib/src/agent/<name>_agent.dart`.
- Demonstrations / example agents: `mobi_nooa_core/example/<name>_agent.dart`.

### 2. Class definition & docstrings
Extend `NooaAgent` and pass `name`, `role`, `description`, and optional `customPromptInstructions` to `super(...)`.

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class MyMobileAgent extends NooaAgent {
  MyMobileAgent()
      : super(
          name: 'MyMobileAgent',
          role: 'Domain Specialist Role',
          description: 'Concise description of the agent purpose and capabilities.',
          customPromptInstructions: 'Special operating instructions provided in system prompt.',
        );
```

### 3. Lazy tool initialization (CRITICAL)
`initAgent()` is invoked in the super constructor before `attachContext(...)` is called. **Never** access `context` synchronously during field initialization or in `initAgent()` body. Instead, use lazy getters:

```dart
  FileEditorTool? _fileEditor;
  FileEditorTool get fileEditor => _fileEditor ??= FileEditorTool(fs: context.harness.fs);
```

### 4. Explicit state initialization
Initialize required state keys inside `initAgent()` via `setState(...)`:

```dart
  @override
  void initAgent() {
    setState('items', <String>[]);
    setState('status', 'idle');
```

### 5. Action registration (`registerAction`)
Register tools / actions in `initAgent()`. Each action must specify:
- `name`: lowerCamelCase identifier.
- `description`: Clear docstring explaining behavior to the LLM.
- `parameters`: List of typed `ToolParameter(...)` definitions.
- `returnType`: String representing return type.
- `invoker`: Async callback receiving `Map<String, dynamic> args`.

```dart
    registerAction(
      name: 'processData',
      description: 'Processes input dataset and updates agent state.',
      parameters: const [
        ToolParameter(
          name: 'inputHandle',
          type: 'string',
          description: 'ObjectHeap handle (#ref_xxx) of input data',
          required: true,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final handle = args['inputHandle'] as String;
        final rawData = context.heap.resolveHandleOrValue(handle);

        // Mutate explicit state
        final status = 'Processed ${handle}';
        setState('status', status);

        // Result is returned (large objects auto-wrapped via ObjectHeap.maybeWrap)
        return {'status': status, 'result': 42};
      },
    );
  }
}
```

### 6. Public API export
If this is a core agent, export it in `mobi_nooa_core/lib/mobi_nooa_core.dart` under `// Agent Core`:
```dart
export 'src/agent/<name>_agent.dart';
```

---

## 🧪 Test-Driven Development (TDD) Workflow

Always write your unit test **before** writing the agent implementation:

1. **RED**: Create `mobi_nooa_core/test/<name>_agent_test.dart`. Use `MockModelClient` to queue expected tool calls, thoughts, and assertions on agent state (`getState`) and tool parameters. Run `dart test` and verify it fails as expected.
2. **GREEN**: Implement `NooaAgent` subclass, register actions, and wire lazy tools until `dart test` passes.
3. **REFACTOR**: Ensure all CodeAct snippets pass `AstGuardrails`, large objects use `ObjectHeap.maybeWrap`, and `dart analyze` reports 0 issues.

---

## Validation

```powershell
cd mobi_nooa_core
dart analyze
dart test
```

Both commands must pass with zero errors and zero warnings.

---

## Checklist

- [ ] **TDD First**: Unit test created with `MockModelClient` asserting tool calls & state before implementation.
- [ ] Subclass extends `NooaAgent` with descriptive `name`, `role`, and `description`.
- [ ] No synchronous access to `context` inside constructor or `initAgent()` (lazy getters used).
- [ ] Agent state initialized and mutated exclusively via `setState(...)`/`getState(...)`.
- [ ] Actions registered with complete `ToolParameter` types and descriptions.
- [ ] Large results wrapped into `ObjectHeap` (pass-by-reference).
- [ ] Exported in `mobi_nooa_core/lib/mobi_nooa_core.dart` (if public).
- [ ] `dart analyze` and `dart test` pass cleanly.
- [ ] `DESIGN.md` / `README.md` updated if introducing a new public agent category.
