---
name: design-mobi-nooa-ui
description: 'Design, generate, iterate, and maintain mobile UI/UX screens for mobi-nooa using Stitch MCP adhering to the Neo-Neural Agentic Interface design system.'
---

# Design mobi-nooa UI with Stitch MCP

Use this skill when asked to create, edit, or maintain UI/UX screens, dashboards, or design components for `mobi-nooa` using **Stitch MCP**.

---

## 🎨 Design System: "Neo-Neural Agentic Interface"

All screens generated for `mobi-nooa` must adhere to the project's Stitch design system:

* **Stitch Project ID**: `448320440128678381`
* **Style Philosophy**: Customer-first, ultra-clean DeepSeek-inspired technical minimalism.
* **Palette (OLED-First Dark Mode)**:
  - Background: Absolute black void (`#000000` / `#121314`) for battery efficiency on OLED screens.
  - Surface Tiers: `#1B1C1C` (low), `#1F2020` (container), `#292A2A` (high), `#343535` (highest).
  - Primary Accent: High-frequency Cyan (`#00E5FF` / `#C3F5FF`) used exclusively for active thinking loops, progress, and primary actions.
  - Subtle Borders: 1px `#1E1E1E` border luminance.
* **Dual Typography**:
  - **Human Dialogue & Headers**: `Inter` (neutral, legible, tight tracking on headers).
  - **Machine Telemetry & Code**: `JetBrains Mono` (status badges, token counters, memory metrics, `#ref_xxx` handles, and AST code blocks).
* **Grid & Density**: 4px base grid, dense-yet-breathable layout tailored for Android mobile form factors.

---

## 📱 The 6 Core Screen Archetypes

When generating or editing screens in Stitch, use `deviceType: "MOBILE"` and model `GEMINI_3_1_PRO`:

1. **Agent Hub & Dashboard (Home)**:
   - Real-time hardware health chips (Battery %, RAM headroom, Thermal state).
   - Reference agent cards carousel (`AutonomousDeviceAgent`, `DataAnalystAgent`, `AutonomousCodingAgent`, `BenchAgent`, `GeneralMobileAgent`).
   - Active model selector badge (**DeepSeek-R1**, DeepSeek-V3, On-Device GGUF, Gemini 1.5, GPT-4o).
   - Operating Mode toggle (`Autonomous`, `Supervised`, `Audit`, `Creator`).

2. **Autonomous Agent Chat & Execution Stream (Core Loop)**:
   - DeepSeek-R1 Expandable `<think>` Reasoning Box with cyan glow and token count.
   - Pass-by-reference `#ref_xxx` ObjectHeap interactive chips with preview bottom sheet.
   - CodeAct sandboxed syntax diff with `AST Security: PASSED` verification pill.
   - Interactive Permission Approval Card (`[Deny]` / `[Approve & Run]`).

3. **Plugin Marketplace & Service Seams (`nooa-plugins`)**:
   - Active plugin toggle cards (`TelemetryLoggerPlugin`, `AuditSecurityPlugin`, `DynamicToolPlugin`).
   - Dynamic tool lambda authoring form.

4. **Session Event Log & Time-Travel Tree (`nooa-session`)**:
   - Visual step scrubber slider (`Step 0 ── Step 1 ── [Step 2] ── Step 3`).
   - Reconstructed state preview at step $k$.
   - `⚡ Fork New Branch from Step k` button.

5. **Two-Way Runtime Skills Catalog (`nooa-skills`)**:
   - Filter chips: `[All]` `[Hardware]` `[Data Science]` `[Coding]` `[Learned Skills]`.
   - Inbound step-by-step checklists and outbound agent-synthesized workflows (`learnSkill`).

6. **Resource Governor & Load Balancer (`nooa-governor`)**:
   - Real-time gauges: RAM pressure, thermal throttling status, battery drain rate.
   - Adaptive execution budget controller and emergency controls (`[Compact Heap]`, `[Pause Background Agents]`).

---

## 🛠️ Step-by-Step Stitch MCP Generation Protocol

```json
// Example: Generating a new screen via Stitch MCP
{
  "projectId": "448320440128678381",
  "deviceType": "MOBILE",
  "modelId": "GEMINI_3_1_PRO",
  "prompt": "Mobile screen for <Feature Name> in mobi-nooa. DeepSeek-inspired technical minimalist dark theme with #00E5FF cyan accents..."
}
```

---

## 🔍 Validation Checklist

- [ ] `projectId` is set to `448320440128678381`.
- [ ] `deviceType` is set to `MOBILE`.
- [ ] Design uses Inter for human text and JetBrains Mono for telemetry/code.
- [ ] Primary buttons use `#00E5FF` solid with black text.
- [ ] DeepSeek reasoning thoughts are styled in collapsible glowing accordions.
- [ ] Large objects use pass-by-reference `#ref_xxx` chips.
