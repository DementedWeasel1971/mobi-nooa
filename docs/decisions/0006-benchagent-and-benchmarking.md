# ADR 0006: BenchAgent, coding tools, and the benchmarking suite

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

The NOOA paper's reference evaluation demonstrates the framework's
effectiveness via a compact `BenchAgent` scored against SWE-bench Verified
and CyberGym. To validate that mobi-nooa's port is faithful and to enable
ongoing regression testing of agent quality, the repo needs both a
reference coding agent and a way to run it against task suites and measure
results.

## Decision

1. Add reusable, harness-backed coding tools under `lib/src/tools/`:
   `ShellHarness`/`LocalShellHarness` (process execution with working-
   directory tracking, timeouts, output truncation), `FileEditorTool`
   (`viewFile`/`strReplace`/`createFile`, mirroring SWE-bench's edit tool
   contract — unique-match-required replacement), and `CodeSearchTool`
   (`findFiles`/`grep`/`extractSymbols`).
2. Add `BenchAgent` (`lib/src/agent/bench_agent.dart`), a `NooaAgent`
   subclass wiring those tools into registered actions
   (`runShell`, `viewFile`, `strReplace`, `createFile`, `grepCode`,
   `listSymbols`), tracking `editedFiles`/`commandHistory` as explicit
   state.
3. Add `lib/src/bench/`: `BenchmarkTask`/`BenchmarkTaskResult`/
   `BenchmarkReport` data model, `BenchmarkSuite.evaluate(agentFactory)`
   running every task against a fresh agent instance and producing a pass
   rate / average steps / total tokens report (plus JSONL export), and
   `swe_bench_runner.dart` / `mobile_bench_runner.dart` for loading
   SWE-bench-style and mobile-specific task suites respectively.

## Alternatives considered

- **Ad-hoc scripts per benchmark** — rejected: would duplicate agent
  wiring and result-reporting logic for every dataset; a shared
  `BenchmarkSuite` keeps evaluation consistent and comparable across runs.
- **Bake benchmark tools directly into `NooaAgent`** — rejected: shell/
  file-edit/code-search capabilities are specific to coding agents, not
  every `NooaAgent`; keeping them in `lib/src/tools/` and composing them
  into `BenchAgent` keeps the base class general-purpose.

## Consequences

- `BenchAgent` is the canonical reference implementation for future coding
  agents; new coding-agent variants should compose `lib/src/tools/*_tool.dart`
  rather than reimplementing shell/file/search logic.
- `BenchmarkSuite` reads `Tracer`/`TokenUsage` data to compute steps-used
  and token totals — any change to tracing event semantics must keep
  `BenchmarkReport` accurate (see `DESIGN.md` design invariant on tracing).
- `mobi_nooa_core/example/run_benchmarks.dart` is the reference wiring
  example for running a suite end-to-end; keep it in sync if the
  `BenchmarkSuite`/`BenchAgent` APIs change.
