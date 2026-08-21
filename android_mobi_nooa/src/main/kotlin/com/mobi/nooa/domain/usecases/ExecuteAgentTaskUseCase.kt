package com.mobi.nooa.domain.usecases

import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.ModelConfig

/**
 * Domain Use Case to validate parameters and orchestrate autonomous agent execution.
 */
class ExecuteAgentTaskUseCase(
    private val repository: AgentRepository
) {
    suspend operator fun invoke(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?> = emptyMap(),
        maxSteps: Int = 10,
        modelConfig: ModelConfig = ModelConfig.Mock,
        operatingMode: AgentOperatingMode = AgentOperatingMode.AUTONOMOUS
    ): Result<AgentExecutionResult> {
        if (agentName.isBlank()) {
            return Result.failure(IllegalArgumentException("Agent name cannot be blank."))
        }
        if (goal.isBlank()) {
            return Result.failure(IllegalArgumentException("Goal cannot be blank."))
        }
        val clampedSteps = maxSteps.coerceIn(1, 50)

        return repository.executeAgent(
            agentName = agentName.trim(),
            goal = goal.trim(),
            inputs = inputs,
            maxSteps = clampedSteps,
            modelConfig = modelConfig,
            operatingMode = operatingMode
        )
    }
}
