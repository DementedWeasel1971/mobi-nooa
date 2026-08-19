# ADR 0003: Pluggable execution strategies via `ExecutionStrategy`

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

Different tasks call for different agent reasoning patterns (explicit
Thought/Action/Observation cycles, direct code generation, upfront
planning, self-critique). Hardcoding one pattern into `AgentLoop` would
force every agent to reason the same way, and would make experimenting
with new patterns (e.g. tree-of-thought, debate) require editing the loop
itself.

## Decision

Define an `ExecutionStrategy` abstract contract
(`lib/src/strategies/execution_strategy.dart`) with two responsibilities:
`buildStrategyPrompt(agent)` (strategy-specific system-prompt instructions)
and `processResponse(...)` (interpret a model response and return a
`StrategyStepResult` telling the loop whether to continue or finish, and
with what tool calls/code snippet). Ship four reference strategies:
`ReActStrategy`, a CodeAct-oriented strategy, `PlanAndSolveStrategy`, and
`SelfReflectionStrategy`.

## Alternatives considered

- **Branch on a strategy enum inside `AgentLoop`** — rejected: doesn't
  scale past a handful of strategies and couples reasoning-pattern logic to
  loop mechanics (message construction, tracing, error handling), which
  should stay orthogonal.
- **One `AgentLoop` subclass per strategy** — rejected: would duplicate the
  loop's step-execution, tracing, and error-handling boilerplate for every
  new reasoning pattern.

## Consequences

- New reasoning patterns are added by implementing `ExecutionStrategy`,
  not by editing `AgentLoop`.
- **Known gap** (tracked here, not yet resolved): as of this ADR,
  `AgentLoop.run` still contains its own hardcoded tool-call vs. code-block
  branching (`lib/src/loop/agent_loop.dart`) rather than delegating
  uniformly to the active `ExecutionStrategy`. Fully routing dispatch
  through `ExecutionStrategy` is follow-up work; until then, both
  mechanisms coexist and new strategy authors should verify their strategy
  is actually being consulted by whatever loop/entry point they use.
