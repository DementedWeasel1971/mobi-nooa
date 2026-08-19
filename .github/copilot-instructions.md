# GitHub Copilot custom instructions

> Full contributor/agent guide: see `AGENTS.md` and `DESIGN.md` at the repo
> root. This file is the entry point Copilot loads automatically for every
> chat, review, and coding-agent session in this repository.

## Project summary

mobi-nooa is a Dart/Kotlin implementation of NVIDIA's NOOA (Object-Oriented
Agents) framework, built for mobile/on-device agentic AI. Two modules:

- `mobi_nooa_core/` — platform-agnostic Dart engine (agents, object heap,
  CodeAct execution, programmable loop, model clients, harnesses, tracing).
- `android_mobi_nooa/` — Android/Kotlin library bridging native device
  capabilities into the Dart core.

## Conventions Copilot must follow

- Keep `mobi_nooa_core` free of any `flutter`/`dart:ui` dependency.
- Export new public Dart classes from `mobi_nooa_core/lib/mobi_nooa_core.dart`.
- New agent state must go through `NooaAgent.setState`/`getState`, not raw
  instance fields.
- Large/complex tool-call return values must be wrapped via
  `ObjectHeap.maybeWrap` (pass-by-reference), not returned inline.
- New model providers implement `ModelClient`; new device/tool capabilities
  implement `HarnessApi` and are named `*_harness.dart`.
- Follow `package:lints/recommended` for Dart; standard Kotlin/Android style
  for the Gradle module.
- After editing Dart code, run `dart analyze` and `dart test` in
  `mobi_nooa_core/`. After editing Kotlin/Gradle code, run `./gradlew build`
  in `android_mobi_nooa/`.
- Architecturally significant changes need an ADR in `docs/decisions/` and a
  `DESIGN.md` update.
- Never commit secrets, API keys, or `local.properties`.

For full detail (build commands, examples, guardrails), read `AGENTS.md`.
