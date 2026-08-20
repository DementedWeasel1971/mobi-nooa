package com.mobi.nooa.domain

import kotlinx.coroutines.flow.StateFlow

/**
 * Domain repository contract for managing, observing, and executing autonomous mobile agents.
 * Follows Google Android Architecture Guidelines.
 */
interface AgentRepository {
    /** Observable reactive state of the agent execution lifecycle. */
    val agentState: StateFlow<AgentState>

    /**
     * Executes an agent task asynchronously and returns a type-safe [AgentExecutionResult].
     */
    suspend fun executeAgent(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?> = emptyMap(),
        maxSteps: Int = 10,
        modelConfig: ModelConfig = ModelConfig.Mock
    ): Result<AgentExecutionResult>

    /**
     * Retrieves the list of agent names registered on the platform bridge.
     */
    suspend fun listRegisteredAgents(): Result<List<String>>

    /**
     * Resets the agent state back to [AgentState.Idle].
     */
    fun resetState()
}
