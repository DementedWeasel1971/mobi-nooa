---
name: technical-writer
description: 'Author, structure, and refine developer-facing and user-facing documentation for mobi-nooa, including architecture guides, API references, getting-started tutorials, and onboarding docs.'
---

# Technical Writer Skill for mobi-nooa

Use this skill when asked to write, structure, or improve documentation for the **mobi-nooa** platform (README files, architecture overviews, developer guides, tutorials, API references, ADRs, or user manuals).

The goal of documentation in `mobi-nooa` is to make mobile on-device object-oriented AI agents intuitive, reproducible, and easy to adopt for mobile engineers (Android/Kotlin, Flutter/Dart), AI/LLM researchers, and open-source contributors.

---

## Core Documentation Principles

1. **Grounded in the 6 NOOA Principles**:
   Always connect features back to the core NOOA architecture ([arXiv:2607.20709](https://arxiv.org/abs/2607.20709)):
   - **Class-as-agent (Principle 1)**: Methods are actions; docstrings/types are contracts.
   - **Pass-by-reference object heap (Principle 2)**: Large objects stay in heap (`#ref_xxx`); context receives bounded previews.
   - **Code as Action (Principle 3)**: Script execution in sandboxed AST runtime.
   - **Programmable loop engineering (Principle 4)**: Explicit loop control and strategies.
   - **Explicit object state (Principle 5)**: Observable state via `setState`/`getState`.
   - **Model-callable harness APIs (Principle 6)**: Hardware and OS capabilities as typed tools.

2. **Accurate & Executable Code Samples**:
   - Every code snippet must be valid, copy-pasteable Dart or Kotlin that matches the current codebase (`mobi_nooa_core/lib/...` and `android_mobi_nooa/...`).
   - Use standard imports (e.g., `import 'package:mobi_nooa_core/mobi_nooa_core.dart';`).
   - Avoid placeholder pseudo-code where concrete implementations exist.

3. **Visual Architecture & Workflows**:
   - Use Mermaid diagrams (`graph TD`, `sequenceDiagram`) to visualize control flows (e.g. LLM $\leftrightarrow$ Loop $\leftrightarrow$ Heap $\leftrightarrow$ Harness $\leftrightarrow$ Native Android Bridge).

4. **Progressive Disclosure & Clear Structure**:
   - **TL;DR / Quickstart**: Enable developers to run an agent in under 3 lines or under 2 minutes.
   - **Concepts & Mental Model**: Explain *why* the architecture is structured this way (e.g. why pass-by-reference prevents prompt blowup).
   - **Deep Dives**: Subsystem architecture (ACT-R memory decay, SQLite checkpointing, AST guardrails).
   - **API Reference Tables**: Clearly tabulate parameters, types, defaults, and return values.

---

## Standard Documentation Blueprints

### Blueprint A: User-Facing Tutorial / Quickstart
When writing tutorials (e.g. "How to build a Battery Monitor Agent", "How to analyze DataFrames with ObjectHeap"):

1. **Title & Objective**: State what the reader will build in one sentence.
2. **Prerequisites**: Minimum SDK versions and dependencies needed.
3. **Complete Working Example**: Full code block with no omitted imports.
4. **Line-by-Line Walkthrough**:
   - How the class represents the agent (`NooaAgent`).
   - How tools are registered (`registerAction`).
   - How state is mutated (`setState`).
   - How dynamic execution is triggered (`ellipsis(...)`).
5. **Running & Expected Output**: Exact CLI commands and terminal output.

### Blueprint B: Subsystem Architecture Guide
When documenting a core subsystem (e.g. `nooa-memory`, `nooa.storage`, `nooa.strategies`):

1. **Purpose & Problem Statement**: What problem does this subsystem solve?
2. **Mathematical / Theoretical Model**: (e.g. ACT-R activation $A_i = B_i + W \cdot \text{Importance} + S_{ji}$ with Ebbinghaus decay).
3. **Key Classes & Responsibilities**: Table of files, classes, and roles.
4. **Data Flow Diagram**: Mermaid flowchart showing request/response cycle.
5. **Code Example**: Real-world usage in an agent.
6. **Configuration Options**: Table of constructor parameters and tuning knobs.

### Blueprint C: Architecture Decision Record (ADR)
When documenting a new architectural choice in `docs/decisions/`:

1. **Status**: Proposed / Accepted / Deprecated.
2. **Context**: What technical constraint or requirement prompted this decision?
3. **Decision**: Clear statement of the architecture chosen.
4. **Consequences**:
   - *Positive*: What benefits or performance improvements are gained?
   - *Negative / Trade-offs*: What constraints or maintenance costs are introduced?
5. **References**: Links to related NOOA principles, PRs, or external papers.

---

## Tone, Style & Formatting Conventions

- **Voice**: Professional, concise, encouraging, and active voice ("Run the benchmark suite" instead of "The benchmark suite can be run").
- **File Links**: Always use clickable GitHub-flavored markdown links (`[ClassName](file:///path/to/file)`).
- **Code Fences**: Always specify language tags (`dart`, `kotlin`, `bash`, `powershell`, `json`, `mermaid`).
- **Callouts**: Use GitHub alert syntax strategically:
  ```markdown
  > [!NOTE]
  > Helpful context or implementation tips.

  > [!IMPORTANT]
  > Critical requirement or architectural constraint.

  > [!WARNING]
  > Potential pitfalls or security rules.
  ```

---

## Technical Writer Quality Checklist

- [ ] Clear overview explaining the "what", "why", and "how".
- [ ] All 6 NOOA principles accurately represented.
- [ ] Code examples verified against live source code (`dart test` and `dart analyze` clean).
- [ ] Mermaid diagrams render valid syntax.
- [ ] Parameter tables include names, types, descriptions, and defaults.
- [ ] Clear instructions for mobile developers (Dart/Flutter & Android/Kotlin).
- [ ] No broken links or obsolete API references.
