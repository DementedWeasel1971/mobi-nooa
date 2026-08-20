# ADR 0008: On-Device LLM Runtime Architecture (llama.cpp + LiteRT-LM)

- **Status**: Accepted
- **Date**: 2026-08-20

## Context

`mobi-nooa` is designed for agentic AI loops on mobile hardware, supporting both cloud-connected and fully offline execution. For on-device inference, mobile environments impose unique constraints:
1. **Memory constraints**: Phones typically have 8–12 GB total RAM, with a practical working budget of 2–4 GB for the LLM weights and KV cache.
2. **Hardware diversity**: Different devices offer varying accelerators (ARM Cortex CPUs with NEON, Adreno/Mali GPUs via OpenCL/Vulkan, and Qualcomm/Google NPUs).
3. **Model ecosystem & Quantization**: GGUF is the de facto standard format for open-source quantized models (Llama 3.2, Qwen 2.5, SmolLM), while LiteRT-LM / MediaPipe targets Android NPU acceleration (Gemma 2).
4. **Lifecycle & Power**: Long-running generation must survive app backgrounding (`ForegroundService`), respect thermal throttling, and handle OS memory pressure (`onTrimMemory`).

Previously, `DESIGN.md` tracked on-device engine selection as an open architecture question, and `OnDeviceModelEngine.kt` was a minimal scaffold.

## Decision

1. **Pluggable Engine Contract (`ILocalInferenceEngine`)**:
   Introduce a unified Kotlin interface in `android_mobi_nooa` that abstracts local model backends behind coroutine- and Flow-based contracts:
   - `loadModel(spec: ModelSpec): Result<Unit>`
   - `unloadModel()`
   - `generate(prompt: String, options: InferenceOptions): Result<GenerationResult>`
   - `generateStream(prompt: String, options: InferenceOptions): Flow<TokenStreamEvent>`
   - `cancel()`
   - `getMemoryFootprint(): Long`

2. **Universal Engine: `llama.cpp` (GGUF + JNI)**:
   Adopt `llama.cpp` embedded via Android NDK / JNI (`LlamaCppInferenceEngine`) as the primary and universal local inference engine. It provides:
   - Direct support for the vast GGUF model ecosystem (Llama 3.2 1B/3B, Qwen 2.5 1.5B/3B, SmolLM 1.7B).
   - Highly optimized ARM64 NEON CPU execution with reliable fallback across all Android devices (API 26+).
   - Fine-grained KV-cache management, token streaming, and instant cancellation.
   - Optional Vulkan compute backend on supported hardware.

3. **Accelerated Secondary Engine: Google LiteRT-LM**:
   Support Google LiteRT-LM (`LiteRtLmInferenceEngine`) as an alternative backend optimized for NPU/GPU acceleration on supported devices (such as Google Pixel Tensor and Qualcomm Snapdragon NPU) for Gemma 2 and compatible LiteRT models.

4. **Model Storage & Integrity via `ModelStorageManager`**:
   Maintain model binaries in app-private storage (`context.filesDir/models/`), enforce SHA-256 verification on download, parse GGUF metadata headers, and expose a recommended catalog of 1B–3B quantized models.

5. **Bridge Integration with Dart Core**:
   `OnDeviceModelClient` in `mobi_nooa_core` formats prompts (ChatML, Llama-3, Gemma) and invokes the native engine via `NativeInferenceBridge` / platform channel (`com.mobi.nooa/model_inference`). An embedded localhost OpenAI-compatible endpoint (`/v1/chat/completions`) can be enabled when external apps or services need to query the local model.

6. **Mobile Safeguards**:
   `OnDeviceModelEngine` integrates with Android OS memory trim notifications (`ComponentCallbacks2.onTrimMemory`) and thermal status listeners (`PowerManager.OnThermalStatusChangedListener`) to dynamically shed KV cache or unload weights during high memory or thermal pressure.

## Alternatives Considered

- **MLC LLM**: Provided strong OpenCL GPU acceleration and built-in OpenAI API, but its compiled-model packaging workflow is significantly more rigid than dynamic GGUF loading and has a smaller open-model catalog.
- **ExecuTorch**: Useful for PyTorch-native export pipelines, but its Android Java runtime is more experimental and less suited as a general GGUF runner.
- **Pure Dart FFI llama.cpp**: While possible, embedding via Kotlin/JNI inside `android_mobi_nooa` allows direct integration with Android's `ForegroundService`, `WorkManager`, thermal monitoring, and memory trimming.

## Consequences

- Resolves the on-device model backend open question in `DESIGN.md`.
- Developers can run local 1B–3B parameter models offline on Android with zero server dependency.
- `OnDeviceModelEngine.kt` is upgraded from a placeholder to a structured engine orchestrator.
- The Dart `OnDeviceModelClient` remains clean and decoupled from native binaries.
