# ADR 0005: AST-level security guardrails for CodeAct

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

CodeAct (NOOA Principle 3) lets the model emit and execute arbitrary code
snippets. Running LLM-authored code on a user's mobile device carries real
risk (process termination, destructive shell patterns, sandbox escapes via
reflection/isolate APIs) beyond what the `SandboxedEnvironment` runtime
sandbox alone should be trusted to catch.

## Decision

Add a pre-execution static validation layer,
`lib/src/security/ast_guardrails.dart`:

- `AstGuardrails.validate(code)` rejects snippets that exceed a length
  limit, contain denylisted identifiers (`exit`, `Process.kill`,
  `dart:mirrors`, `dart:isolate.spawnUri`, `System.exit`,
  `Runtime.getRuntime`), or match denylisted regex patterns (`rm -rf /`,
  disk-format commands, shell fork bombs).
- Returns an `AstValidationResult` with a structured list of violations,
  rather than throwing, so callers can surface a corrective message back to
  the model instead of hard-failing the loop.

This is a **defense-in-depth** layer: it complements, and does not replace,
runtime sandboxing in `SandboxedEnvironment`/`CodeActEngine`.

## Alternatives considered

- **Runtime sandboxing only, no static pre-check** — rejected: some
  destructive actions (e.g. shelling out to `rm -rf /`) may not be
  reliably interceptable purely at the sandbox boundary depending on how
  the sandbox is implemented; a cheap static denylist check catches the
  common/obvious cases before any execution is attempted.
- **Full AST parse + semantic analysis** — deferred: `AstGuardrails`
  currently does substring/regex matching, not true AST parsing, despite
  the name. This is intentionally lightweight; if bypass patterns are
  found in practice, upgrading to real AST-based analysis is future work
  and should get its own ADR superseding this one.

## Consequences

- Every code path that executes an LLM-authored snippet must call
  `AstGuardrails.validate` first (see `AGENTS.md` guardrails) — this is a
  single choke point, not optional per-call-site behavior.
- The denylists are maintainable constants on `AstGuardrails`; expanding
  them is a low-risk, non-architectural change and does not need a new ADR
  unless the validation *mechanism* itself changes (e.g. moving to real AST
  parsing).
