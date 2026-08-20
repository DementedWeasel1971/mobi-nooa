# ADR 0010: Adaptive On-Device Resource Governor & Agent Load Balancer (`nooa-governor`)

## Status
Accepted

## Context
Running continuous autonomous agent loops, CodeAct evaluators, and quantized local LLMs (e.g. 1B–8B GGUF weights via `llama.cpp` or LiteRT-LM) directly on mobile devices introduces severe hardware constraints:
1. **RAM Headroom & OOM Risks**: Local models consume 1.5GB–5.5GB of RAM. If multi-agent loops or large `ObjectHeap` buffers exhaust free memory, Android's Low Memory Killer (`lmkd`) terminates the host application.
2. **Thermal Buildup & Throttling**: Sustained CPU/GPU/NPU inference generates heat. Once thermal limits are breached, OS thermal governors throttle clock frequencies to 20%–40%, severely degrading tokens/second.
3. **Battery Drain**: Continuous unconstrained background agent reasoning on battery quickly depletes user devices.
4. **Metered Cellular Overdraw**: Running heavy multimodal or cloud models on metered mobile cellular connections instead of unmetered Wi-Fi.

Without an intelligent on-device resource governor, the application risks overdrawing hardware, causing thermal throttling, OOM crashes, or excessive battery consumption.

## Decision
We implement **`DeviceResourceGovernor`** and **`AgentLoadBalancer`** (`nooa-governor`) in `mobi_nooa_core/lib/src/governor/resource_governor.dart` coupled with hardware telemetry in `DeviceHarness` and `DeviceHarnessBridge.kt`:

1. **Hardware Introspection**:
   - `DeviceStatus` / `DeviceHarnessBridge`: Introspects real-time battery level, charging state, available RAM (`ActivityManager.MemoryInfo`), thermal throttling headroom (`PowerManager.currentThermalStatus` / `ThermalState`), and network meteredness.
2. **Adaptive Execution Budget (`ExecutionBudget`)**:
   - Produces a real-time `ExecutionBudget` with:
     - `pressureLevel`: `nominal`, `moderate`, `high`, `critical`.
     - `recommendedModelTier`: `onDeviceLarge`, `onDeviceStandard`, `onDeviceTiny`, `cloudOffload`, `paused`.
     - `maxConcurrentAgents`: Dynamically caps parallel agent loops (e.g. 4 on nominal, 2 on moderate, 1 on high, 0 / paused on critical).
     - `stepPacingDelayMs`: Injects adaptive cooling delays between reasoning steps during thermal elevation.
     - `shouldTriggerHeapCompaction`: Requests `ObjectHeap` to evict cached previews and unreferenced handles under memory pressure.
     - `shouldPauseBackgroundAgents`: Checkpoints and pauses non-urgent background tasks when battery is low (< 15%) or RAM is tight.
3. **Cloud-Offload & Tier Load Balancing**:
   - Under severe thermal pressure or low RAM, the governor shifts execution from heavy on-device NPU/GPU inference to lightweight cloud inference (`cloudOffload`) or tiny quantized models (`onDeviceTiny`), eliminating device heat.
4. **Agent-Facing Governor Tools**:
   - `AutonomousDeviceAgent` exposes `assessResourceHeadroom` and `applyGovernorPolicy` tools, allowing the agent to self-regulate, balance workloads, and notify the user before overdrawing hardware.

## Consequences

### Positive
- **Guaranteed Device Stability**: Prevents Android OOM process termination and aggressive OS thermal throttling.
- **Dynamic Load Balancing**: Multi-agent tasks scale concurrency and model tiers up or down automatically based on real-time hardware headroom.
- **Battery Preservation**: Automatically pauses background tasks and enables eco-pacing when running on low battery.
- **Platform Agnostic with Android Grounding**: Core governor logic is pure Dart; Android `DeviceHarnessBridge.kt` supplies live OS metrics.

### Negative / Trade-offs
- Background agents may be temporarily delayed when the device is under thermal or battery stress until conditions normalize.
