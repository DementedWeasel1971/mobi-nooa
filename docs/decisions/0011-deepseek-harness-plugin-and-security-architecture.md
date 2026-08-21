# ADR 0011: DeepSeek Harness Architecture Integration (Plugins, Tiered Permissions, Session Event Logs & DeepSeek-R1/V3)

## Status
Accepted

## Context
As agentic workflows expand from single-task assistants to continuous, autonomous on-device mobile systems, two major challenges arise:
1. **Monolithic Framework Tight-Coupling**: In traditional architectures, tools, models, harnesses, middleware, and storage backends are hard-coded into the agent core, preventing dynamic plugin loading, runtime tool injection, or enterprise policy swapping.
2. **Mobile Authorization & Security Invariants**: On Android mobile hardware, agents have access to telephony, notifications, vibration, local storage, SQLite databases, and shell execution. An all-or-nothing security model is insufficient: safe read tools must run autonomously without blocking the user, while mutating or destructive actions require granular, policy-driven authorization and interactive user approval callbacks.
3. **DeepSeek-R1 / DeepSeek-V3 Reasoning**: Modern reasoning models output dedicated thinking streams (`reasoning_content`, `<think>` XML tags) and utilize prompt prefix caching that requires discrete tracking in token usage and agent loops.
4. **Append-Only Auditing & Time-Travel/Forking**: Debugging, checkpointing, and exploring alternative agent execution paths require an append-only event log with historical replay and branching/forking capabilities.

DeepSeek AI's **DeepSeek Harness** (`dsh`) pioneered a "Everything is a Plugin" (service seam) architecture and decoupled permission policy model.

## Decision
We adopt and faithfully port DeepSeek Harness's key architectural advancements into `mobi_nooa_core`:

1. **"Everything is a Plugin" (`AgentPlugin` & `PluginRegistry`)**:
   - `AgentPlugin`: Defines a modular lifecycle (`initialize`, `dispose`), dynamic action contributions (`providedActions`), and interception hooks (`onBeforeStep`, `onAfterStep`, `onBeforeToolExecution`, `onAfterToolExecution`, `onAgentFinished`, `onError`).
   - `PluginRegistry`: Central registry managing active plugins, aggregating actions, and dispatching lifecycle hooks.
   - Built-in plugins: `TelemetryLoggerPlugin` (structured JSONL event streaming), `AuditSecurityPlugin` (real-time argument policy inspection), `DynamicToolPlugin` (runtime lambda action registration).

2. **Decoupled Tiered Permission Engine (`PermissionManager` & `PermissionPolicy`)**:
   - Decouples authorization rules from tool implementations.
   - 4 Permission Tiers: `allow` (unconditional execution), `prompt` (requires interactive `ApprovalCallback`), `deny` (strictly forbidden), and `quarantine` (sandboxed/simulated).
   - Standard mobile profiles: `PermissionPolicy.defaultMobile()` (auto-allows telemetry/reads; prompts on disk/shell/SMS mutations), `PermissionPolicy.strictAudit()` (read-only audit mode), `PermissionPolicy.permissive()` (unconstrained execution for unit tests).

3. **Append-Only Session Event Log, Replay & Forking (`SessionEventLog`)**:
   - Immutable chronological event model (`SessionEvent`) recording user prompts, assistant thoughts, tool calls, tool results, CodeAct snippets, state mutations, and errors.
   - **Time-Travel Replay** (`replay(toStepIndex)`): Reconstructs agent state snapshot at step $k$.
   - **Session Branching / Forking** (`fork(newSessionId, fromStepIndex)`): Forks an existing session from historical step $k$ into an independent branch for speculative exploration or rollback.
   - JSON / JSONL serialization for SQLite and cloud synchronization.

4. **First-Class DeepSeek Model Client (`DeepSeekClient`)**:
   - Native support for `deepseek-chat` (DeepSeek-V3) and `deepseek-reasoner` (DeepSeek-R1).
   - Automatic extraction of `reasoning_content` and `<think>` XML blocks into `ModelResponse.reasoningContent`.
   - Prompt prefix cache telemetry (`prompt_cache_hit_tokens`, `prompt_cache_miss_tokens`).
   - Configurable base URL overrides (`api.deepseek.com`, SiliconFlow, OpenRouter, Ollama local GGUF).

5. **Agent Operating Modes (`AgentOperatingMode`)**:
   - `autonomous`: Standard autonomous loop.
   - `supervised`: Interactive mode requiring approval for mutating actions.
   - `audit`: Read-only telemetry mode blocking all mutations.
   - `creator`: Optimized for skill authoring and reflection loops.

## Consequences

### Positive
- **Modular Extensibility**: Developers and enterprises can inject custom harnesses, security rules, and telemetry collectors without modifying the agent core.
- **Strict Mobile Safety**: Guarantees Android apps can enforce fine-grained user permissions over sensitive actions (SMS, shell, file writes) while preserving autonomous reads.
- **Deep Reasoning Integration**: DeepSeek-R1 / V3 reasoning steps are captured and rendered distinctly from final responses.
- **Auditable & Replayable**: Full session provenance with historical time-travel replay and speculative branching.
