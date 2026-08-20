# ADR 0009: Two-Way Runtime Agent Skills Subsystem (nooa-skills)

- **Status**: Accepted
- **Date**: 2026-08-20

## Context

`mobi-nooa` executes agent loops across diverse model backends — from frontier cloud models (Gemini 1.5 Pro, Claude 3.5 Sonnet, GPT-4o) to compact, quantized on-device models (Llama 3.2 1B/3B, Qwen 2.5 1.5B/3B, Gemma 2 2B) running locally on Android mobile hardware.

While tools define *what an agent can do* and cognitive memory stores *what an agent knows*, smaller on-device models struggle with open-ended zero-shot planning, parameter validation, and complex multi-step tool choreography. Without procedural guidance, 1B–3B models frequently suffer from hallucinations, missed preconditions, or loop drift.

A structured **Skills Mechanism** provides model-invariant consistency by providing deterministic procedural knowledge (workflows, checklists, validation rules, few-shot examples) that can be retrieved and executed by any model.

## Decision

Introduce the **`nooa-skills`** subsystem under `mobi_nooa_core/lib/src/skills/` with two-way ("to and from the agent") capability:

1. **Structured Skill Model (`Skill`)**:
   - Encapsulates procedural knowledge: `id`, `name`, `description`, `tags`, `requiredTools`, `instructions` (step-by-step recipe / checklist), and `examples`.
   - Serializable to and from JSON/Markdown formats for storage and inspection.

2. **Skill Catalog & Store (`SkillStore`)**:
   - `SkillStore` contract with `InMemorySkillStore` and `FileSystemSkillStore`.
   - Supports keyword, tag, and fuzzy/embedding-based matching (`findSkills(query)`).
   - Ships with a built-in seed catalog of standard mobile triage, coding, and benchmark execution skills.

3. **Inbound Skills (TO the Agent — Retrieval & Prompt Enhancement)**:
   - When a task goal is submitted to `AgentLoop` or `NooaAgent`, `SkillPromptEnhancer` matches relevant skills from the store and injects their execution checklists and constraints into the LLM system prompt.
   - Provides 1B–3B on-device models with strict recipes, elevating their execution reliability to near frontier-model consistency.

4. **Outbound Skills (FROM the Agent — Synthesis & Continuous Learning)**:
   - Expose `SkillHarness` in `HarnessApi` (implementing NOOA Principle 6: Model-Callable Harness APIs).
   - Allows agents running on frontier models, or recovering from errors via `SelfReflectionStrategy`, to synthesize and persist newly discovered procedures (`createSkill`) into the `SkillStore`.
   - Newly learned skills become immediately available offline for small local models.

## Alternatives Considered

- **Embedding-Only Few-Shot Memory in `CognitiveMemoryStore`**: Rejected because cognitive memory stores unstructured factual/episodic texts scored with ACT-R decay, whereas skills represent structured, permanent procedural recipes with explicit tool dependencies and verification steps.
- **Hardcoding Prompts in Agent Classes**: Rejected because hardcoding prevents dynamic skill discovery, multi-agent skill sharing, runtime extension without code changes, and dynamic skill synthesis by the agent.

## Consequences

- Bridges the reasoning gap between large cloud models and small on-device models.
- Provides a reusable, exportable repository of procedural skills.
- Enables autonomous self-learning: agents can learn procedures once and reuse them indefinitely.
- Adds `SkillHarness` to `HarnessApi` without breaking existing agent code.
