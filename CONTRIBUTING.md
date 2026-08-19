# Contributing

This repo is developed collaboratively with AI coding agents. Human and AI
contributors should follow the same workflow.

## Before you start

1. Read `AGENTS.md` (conventions, build/test commands, guardrails).
2. Read `DESIGN.md` (architecture and invariants).
3. Skim `docs/decisions/` for relevant prior decisions.

## Workflow

1. Keep changes small and single-purpose.
2. Run the relevant validation before committing:
   - Dart: `dart analyze && dart test` from `mobi_nooa_core/`
   - Android: `./gradlew build` from `android_mobi_nooa/`
3. If your change affects architecture, a NOOA principle's implementation,
   or a module boundary, add an ADR under `docs/decisions/` (copy
   `docs/decisions/0000-template.md`) and update `DESIGN.md`.
4. Write commit messages that state *what* changed and *why*.

## Style

- Dart: `package:lints/recommended`, 2-space indent, doc comments on all
  public members (they double as LLM prompt contracts — see `AGENTS.md`).
- Kotlin: standard Android Kotlin style guide.

## Asking questions

If a task is ambiguous (which provider to support next, which harness to
prioritize, how to bridge Dart↔Kotlin), stop and ask rather than guessing —
record the resolution as an ADR once decided.
