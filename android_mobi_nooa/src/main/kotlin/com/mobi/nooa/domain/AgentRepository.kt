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
        modelConfig: ModelConfig = ModelConfig.Mock,
        operatingMode: AgentOperatingMode = AgentOperatingMode.AUTONOMOUS
    ): Result<AgentExecutionResult>

    /**
     * Retrieves the list of agent names registered on the platform bridge.
     */
    suspend fun listRegisteredAgents(): Result<List<String>>

    /**
     * Replays a historical session up to [stepIndex].
     */
    suspend fun replaySession(sessionId: String, stepIndex: Int): Result<Map<String, Any?>>

    /**
     * Forks a historical session into a new branch from [fromStepIndex].
     */
    suspend fun forkSession(sessionId: String, newSessionId: String, fromStepIndex: Int): Result<Map<String, Any?>>

    /**
     * Retrieves live hardware telemetry from the device harness.
     */
    suspend fun getHardwareTelemetry(): Result<HardwareTelemetry>

    /**
     * Assesses execution budget based on current battery, thermals, and RAM.
     */
    suspend fun assessGovernorBudget(): Result<GovernorBudget>

    /**
     * Retrieves the list of active and available plugins.
     */
    suspend fun listPlugins(): Result<List<PluginInfo>>

    /**
     * Resets the agent state back to [AgentState.Idle].
     */
    fun resetState()
}
