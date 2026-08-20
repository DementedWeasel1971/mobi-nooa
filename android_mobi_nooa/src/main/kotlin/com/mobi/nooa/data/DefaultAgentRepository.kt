package com.mobi.nooa.data

import com.mobi.nooa.MobiNooaBridge
import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.ModelConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

/**
 * Production implementation of [AgentRepository] bridging Kotlin domain operations
 * to the headless Dart execution engine via [MobiNooaBridge].
 */
class DefaultAgentRepository(
    private val bridge: MobiNooaBridge
) : AgentRepository {

    private val _agentState = MutableStateFlow<AgentState>(AgentState.Idle)
    override val agentState: StateFlow<AgentState> = _agentState.asStateFlow()

    override suspend fun executeAgent(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?>,
        maxSteps: Int,
        modelConfig: ModelConfig
    ): Result<AgentExecutionResult> = withContext(Dispatchers.Default) {
        _agentState.value = AgentState.Running(
            agentName = agentName,
            goal = goal,
            currentStep = 1,
            maxSteps = maxSteps
        )

        val startTime = System.currentTimeMillis()
        val (provider, apiKey) = when (modelConfig) {
            is ModelConfig.Mock -> "mock" to null
            is ModelConfig.OnDevice -> "on_device" to null
            is ModelConfig.Cloud -> modelConfig.provider to modelConfig.apiKey
        }

        try {
            val response = bridge.runAgentLoop(
                agentName = agentName,
                goal = goal,
                inputs = inputs,
                maxSteps = maxSteps,
                modelProvider = provider,
                modelApiKey = apiKey
            )

            val duration = System.currentTimeMillis() - startTime
            val error = response["error"] as? String

            if (error != null) {
                val failure = AgentExecutionResult(
                    agentName = agentName,
                    goal = goal,
                    resultText = "",
                    isSuccess = false,
                    stepCount = (response["stepCount"] as? Number)?.toInt() ?: 1,
                    durationMs = duration,
                    errorMessage = error
                )
                val ex = IllegalStateException(error)
                _agentState.value = AgentState.Failed(agentName, goal, error, ex)
                Result.failure(ex)
            } else {
                val resultText = response["result"]?.toString() ?: ""
                @Suppress("UNCHECKED_CAST")
                val trace = (response["trace"] as? List<Map<String, Any?>>) ?: emptyList()
                val stepCount = (response["stepCount"] as? Number)?.toInt() ?: 1

                val executionResult = AgentExecutionResult(
                    agentName = agentName,
                    goal = goal,
                    resultText = resultText,
                    isSuccess = true,
                    stepCount = stepCount,
                    durationMs = duration,
                    trace = trace
                )

                _agentState.value = AgentState.Success(executionResult)
                Result.success(executionResult)
            }
        } catch (e: Exception) {
            _agentState.value = AgentState.Failed(agentName, goal, e.message ?: "Unknown bridge error", e)
            Result.failure(e)
        }
    }

    override suspend fun listRegisteredAgents(): Result<List<String>> = withContext(Dispatchers.Default) {
        try {
            val response = bridge.listAgents()
            @Suppress("UNCHECKED_CAST")
            val agents = (response["agents"] as? List<String>) ?: emptyList()
            Result.success(agents)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun resetState() {
        _agentState.value = AgentState.Idle
    }
}
