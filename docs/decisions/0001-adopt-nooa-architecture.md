# ADR 0001: Adopt NVIDIA NOOA architecture, ported to Dart/Kotlin

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

We want a mobile-first agentic AI framework that runs efficiently on-device
(Android to start) with a clean separation between provider-agnostic agent
logic and platform-specific capability bridges. NVIDIA's NOOA
(*labs-OO-Agents*, arXiv:2607.20709) provides a well-specified
object-oriented agent design (explicit state, pass-by-reference heap,
CodeAct execution, programmable loop, model-callable harnesses) with a
reference Python implementation.

## Decision

Port NOOA's core abstractions faithfully into a pure Dart library
(`mobi_nooa_core`), keeping it Flutter/UI-free, and add an Android Kotlin
library module (`android_mobi_nooa`) to bridge native device capabilities.
Six principles are preserved 1:1 (see `DESIGN.md`).

## Alternatives considered

- **Write a from-scratch mobile agent framework** — rejected: NOOA's design
  already solves the hard problems (context bloat via heap references,
  observability via tracing, code-as-action) and a faithful port lets us
  track upstream research improvements.
- **Implement directly in Kotlin only** — rejected: Dart/Flutter gives a
  path to iOS reuse later without a second rewrite; Kotlin module stays
  focused on Android-specific bridging only.

## Consequences

- Two-module structure (`mobi_nooa_core` + `android_mobi_nooa`) must be
  maintained; the Dart core must never gain a Flutter dependency.
- A bridge mechanism between the modules is still an open question (see
  `DESIGN.md` § Open architecture questions) and needs its own ADR before
  implementation.
