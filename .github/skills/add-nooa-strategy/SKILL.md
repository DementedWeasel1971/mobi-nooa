---
name: add-nooa-strategy
description: 'Add a new agent execution strategy (ExecutionStrategy implementation) to mobi_nooa_core (NOOA Principle 4: programmable loop engineering).'
---

# Add a NOOA Execution Strategy

Use this skill when asked to add a new reasoning or loop execution strategy to `mobi_nooa_core` (e.g. tree-of-thoughts, debate/multi-agent critic, Monte Carlo tree search, iterative refinement, human-in-the-loop approval).

Strategies implement **NOOA Principle 4: programmable loop engineering** — they decouple reasoning control flow and prompt structures from the mechanics of the step execution loop (`AgentLoop`).

---

## Reference implementations (read before writing code)

- `mobi_nooa_core/lib/src/strategies/execution_strategy.dart` — base contract and `StrategyStepResult`
- `mobi_nooa_core/lib/src/strategies/react_strategy.dart` — Thought → Action → Observation cycling
- `mobi_nooa_core/lib/src/strategies/code_act_strategy.dart` — code-first snippet emission
- `mobi_nooa_core/lib/src/strategies/plan_and_solve_strategy.dart` — upfront plan generation followed by sequential execution
- `mobi_nooa_core/lib/src/strategies/self_reflection_strategy.dart` — error reflection and revision

---

## Pattern to follow

### 1. File placement
Create `mobi_nooa_core/lib/src/strategies/<name>_strategy.dart`.

### 2. Implement `ExecutionStrategy`
Implement `name`, `description`, `buildStrategyPrompt(NooaAgent agent)`, and `processResponse(...)`:

```dart
import 'dart:async';
import 'execution_strategy.dart';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';
import '../loop/step_event.dart';

class MyCustomStrategy implements ExecutionStrategy {
  @override
  final String name = 'MyCustomStrategy';

  @override
  final String description =
      'Custom reasoning strategy description.';

  @override
  String buildStrategyPrompt(NooaAgent agent) {
    return '''
Instructions for the LLM on how to format thoughts, decisions, and step progression.
''';
  }

  @override
  Future<StrategyStepResult> processResponse({
    required NooaAgent agent,
    required ModelResponse modelResponse,
    required List<StepExecution> history,
  }) async {
    // If model made tool calls, continue the loop
    if (modelResponse.hasToolCalls) {
      return StrategyStepResult.continueLoop(
        thought: modelResponse.text,
        toolCalls: modelResponse.toolCalls,
      );
    }

    // Determine completion vs continuation
    if (/* completion condition */) {
      return StrategyStepResult.finish(modelResponse.text.trim());
    }

    return StrategyStepResult.continueLoop(
      thought: modelResponse.text,
    );
  }
}
```

### 3. Public API export
Export in `mobi_nooa_core/lib/mobi_nooa_core.dart` under `// Execution Strategies (nooa.strategies)`:
```dart
export 'src/strategies/<name>_strategy.dart';
```

### 4. Tests
Add test cases in `mobi_nooa_core/test/strategies_and_storage_test.dart` asserting that the strategy correctly continues the loop or signals completion based on model response outputs.

---

## Validation

```powershell
cd mobi_nooa_core
dart analyze
dart test
```

---

## Checklist

- [ ] `<name>_strategy.dart` implements `ExecutionStrategy` contract.
- [ ] Returns `StrategyStepResult.continueLoop(...)` or `StrategyStepResult.finish(...)`.
- [ ] Exported in `mobi_nooa_core/lib/mobi_nooa_core.dart`.
- [ ] Unit tests added in `mobi_nooa_core/test/`.
- [ ] `dart analyze` and `dart test` pass cleanly.
