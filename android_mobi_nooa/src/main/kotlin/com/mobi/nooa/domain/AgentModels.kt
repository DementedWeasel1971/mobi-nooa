package com.mobi.nooa.domain

/**
 * Model configuration options for executing an agent.
 */
sealed class ModelConfig {
    data object Mock : ModelConfig()
    data class OnDevice(val template: String = "llama3") : ModelConfig()
    data class DeepSeek(val modelName: String = "deepseek-reasoner", val apiKey: String?) : ModelConfig()
    data class Nvidia(val modelName: String = "meta/llama-3.3-70b-instruct", val apiKey: String?) : ModelConfig()
    data class Cloud(val provider: String, val modelName: String? = null, val apiKey: String?) : ModelConfig()
}

/**
 * Operating modes for agent execution safety.
 */
enum class AgentOperatingMode {
    AUTONOMOUS,
    SUPERVISED,
    AUDIT,
    CREATOR
}

/**
 * Type-safe execution result returned from an autonomous agent loop.
 */
data class AgentExecutionResult(
    val agentName: String,
    val goal: String,
    val resultText: String,
    val isSuccess: Boolean,
    val stepCount: Int = 1,
    val durationMs: Long = 0,
    val trace: List<Map<String, Any?>> = emptyList(),
    val state: Map<String, Any?> = emptyMap(),
    val heapHandles: List<String> = emptyList(),
    val errorMessage: String? = null
)

/**
 * Reactive state of the autonomous agent engine for Android UI & ViewModel observability.
 */
sealed interface AgentState {
    /** Agent engine is idle and ready to receive instructions. */
    data object Idle : AgentState

    /** Agent is actively executing a task. */
    data class Running(
        val agentName: String,
        val goal: String,
        val currentStep: Int = 1,
        val maxSteps: Int = 10,
        val latestThought: String? = null,
        val reasoningContent: String? = null
    ) : AgentState

    /** Agent finished task execution successfully. */
    data class Success(
        val result: AgentExecutionResult
    ) : AgentState

    /** Agent failed or encountered an unrecoverable error. */
    data class Failed(
        val agentName: String,
        val goal: String,
        val error: String,
        val cause: Throwable? = null
    ) : AgentState
}

/**
 * Metadata for a registered agent capability.
 */
data class AgentInfo(
    val name: String,
    val role: String,
    val description: String,
    val isReady: Boolean = true
)

/**
 * Hardware and system telemetry snapshot.
 */
data class HardwareTelemetry(
    val batteryLevel: Float,
    val isCharging: Boolean,
    val availableRamMb: Int,
    val totalRamMb: Int,
    val thermalStatus: String,
    val networkStatus: String,
    val isLowRam: Boolean = false
) {
    val ramUsagePercent: Int
        get() = if (totalRamMb > 0) (((totalRamMb - availableRamMb).toFloat() / totalRamMb) * 100).toInt() else 0
}

/**
 * Adaptive execution resource budget from governor.
 */
data class GovernorBudget(
    val maxConcurrency: Int = 4,
    val recommendedTier: String = "on_device",
    val stepDelayMs: Long = 0L,
    val isCloudOffloadRecommended: Boolean = false
)

/**
 * Metadata for registered plugins.
 */
data class PluginInfo(
    val name: String,
    val version: String,
    val description: String,
    val isEnabled: Boolean = true,
    val providedTools: List<String> = emptyList()
)

/**
 * Session snapshot metadata.
 */
data class SessionInfo(
    val sessionId: String,
    val eventCount: Int,
    val lastActiveTimestamp: Long = System.currentTimeMillis(),
    val currentState: Map<String, Any?> = emptyMap()
)

/**
 * Interactive permission approval request for mobile UI.
 */
data class PermissionApprovalRequest(
    val actionName: String,
    val arguments: Map<String, Any?>,
    val tier: String = "prompt",
    val reason: String = "Sensitive action requires user confirmation"
)
