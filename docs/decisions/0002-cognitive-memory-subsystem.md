# ADR 0002: Cognitive long-term memory with ACT-R activation and owner-gating

- **Status**: Accepted
- **Date**: 2026-08-19

## Context

Short-term, session-scoped state already existed via `MemoryHarness` (a
simple KV + cosine-similarity vector store in `lib/src/harness/`). Agents
also need **long-term** memory that persists and degrades/reinforces over
time the way human memory does, and — since multiple agents/subagents can
share a process — that memory must not leak across agent/owner boundaries.

## Decision

Introduce a separate `nooa-memory` subsystem (`lib/src/memory/`) distinct
from the harness-layer `MemoryHarness`:

- `CognitiveMemoryRecord` + `ActRActivationCalculator` implement an ACT-R
  style activation score combining Ebbinghaus power-law base-level decay
  (`B_i = ln(Σ (t - t_k)^-d)`), an importance weight, and contextual
  (embedding) similarity.
- `CognitiveMemoryStore` ranks/recalls records by this activation score and
  reinforces on access (each `recall` re-records an access event).
- `OwnerGatedMemoryScope` wraps a store and strictly scopes all
  `remember`/`recall` calls to one `ownerId`, so per-agent/subagent memory
  isolation is enforced by construction rather than by convention alone.

## Alternatives considered

- **Reuse `MemoryHarness` for long-term memory too** — rejected: the
  harness's flat KV/vector interface has no concept of decay, importance,
  or owner scoping; conflating short-term working memory with long-term
  cognitive memory would blur two genuinely different retention models.
- **No owner gating (single shared store)** — rejected: unsafe once
  `NooaAgent.spawnSubagent` is used for multi-agent decomposition; a
  subagent could read/write another agent's memories.

## Consequences

- Any code accessing long-term memory in a multi-agent context must go
  through `OwnerGatedMemoryScope`, not a raw `CognitiveMemoryStore` call
  with an arbitrary `ownerId` (see `AGENTS.md` guardrails).
- Two memory systems now coexist (`harness/memory_harness.dart` for
  session-scoped KV/vector, `memory/act_r_memory.dart` for long-term
  cognitive recall) — this distinction must be preserved and documented
  wherever both are referenced (see `DESIGN.md`).
