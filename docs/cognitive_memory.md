# Cognitive Memory & ACT-R Theory (`nooa-memory`)

The `nooa-memory` subsystem in **`mobi-nooa`** provides cognitively grounded, persistent long-term memory for on-device AI agents. Unlike standard vector databases that only rank by static semantic cosine similarity, `mobi-nooa` ranks memories using principles of human memory retention, rehearsal reinforcement, and Ebbinghaus forgetting curves.

---

## 🧠 1. The Mathematical Model

### ACT-R Base-Level Activation Equation
The retrieval strength (activation $A_i$) of a memory item $i$ at time $t$ is defined as:

$$A_i = B_i + W_{\text{importance}} \cdot \text{Importance}_i + S_{\text{context}} + \epsilon$$

Where:
- $B_i$: **Base-level activation** reflecting practice and decay over time.
- $W_{\text{importance}}$: Scaling factor for explicit importance weights (0.0 to 1.0).
- $S_{\text{context}}$: Spreading activation bonus from contextual similarity (e.g. embedding cosine similarity).
- $\epsilon$: Stochastic noise component.

### Ebbinghaus Power-Law of Forgetting
Base-level activation decays exponentially according to the Ebbinghaus forgetting curve across all prior access timestamps $t_k$:

$$B_i = \ln \left( \sum_{k=1}^n (t - t_k)^{-d} \right)$$

- $t - t_k$: Elapsed seconds since the $k$-th rehearsal/access event.
- $d$: Power-law decay parameter (typically $d = 0.5$ in cognitive psychology).

---

## 🔒 2. Owner-Gated Multi-Tenant Isolation

In multi-agent or multi-user mobile environments, agent memories must never leak across ownership boundaries. 

`OwnerGatedMemoryScope` wraps a `CognitiveMemoryStore` and strictly filters read and write operations by `ownerId`:

```dart
final memoryStore = CognitiveMemoryStore();

// Agent A Scope
final agentAScope = OwnerGatedMemoryScope(ownerId: 'agent_A', store: memoryStore);
agentAScope.remember(
  id: 'secret_token',
  content: 'Agent A private token: abc-123',
  tags: ['auth'],
);

// Agent B Scope
final agentBScope = OwnerGatedMemoryScope(ownerId: 'agent_B', store: memoryStore);
final recalls = agentBScope.recall();

// Result: recalls.length == 0 (Agent B cannot access Agent A's memory)
```

---

## ⚡ 3. Memory Reinforcement on Recall

Every time a memory record is recalled via `store.recall(...)` or `scope.recall(...)`, an access event timestamp is automatically recorded (`recordAccess()`). 

This mimics cognitive rehearsal: **frequently recalled memories maintain high activation and stay at the top of retrieval ranks**, while unreferenced facts gradually decay below retrieval thresholds.

---

## 📊 4. Cognitive Memory API Reference

| Class / Method | Description |
|---|---|
| `CognitiveMemoryRecord` | Represents a stored memory item with `id`, `ownerId`, `content`, `tags`, `importance`, `accessHistory`, `embedding`, and `metadata`. |
| `ActRActivationCalculator` | Computes $A_i$ using power-law decay ($d=0.5$) and importance weights. |
| `CognitiveMemoryStore` | In-memory/SQLite store with `remember(...)`, `recall(...)`, and `clear()`. |
| `OwnerGatedMemoryScope` | Security scope wrapper enforcing single-owner memory isolation. |
