package com.mobi.nooa.domain

/**
 * Model configuration options for executing an agent.
 */
sealed class ModelConfig {
    data object Mock : ModelConfig()
    data class OnDevice(val template: String = "llama3") : ModelConfig()
    data class Cloud(val provider: String, val apiKey: String?) : ModelConfig()
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
        val maxSteps: Int = 10
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
