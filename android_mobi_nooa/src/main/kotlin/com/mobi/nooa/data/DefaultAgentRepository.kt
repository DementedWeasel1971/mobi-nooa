package com.mobi.nooa.data

import com.mobi.nooa.MobiNooaBridge
import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.GovernorBudget
import com.mobi.nooa.domain.HardwareTelemetry
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.domain.PluginInfo
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
        modelConfig: ModelConfig,
        operatingMode: AgentOperatingMode
    ): Result<AgentExecutionResult> = withContext(Dispatchers.Default) {
        _agentState.value = AgentState.Running(
            agentName = agentName,
            goal = goal,
            currentStep = 1,
            maxSteps = maxSteps
        )

        val startTime = System.currentTimeMillis()
        val (provider, apiKey, modelName) = when (modelConfig) {
            is ModelConfig.Mock -> Triple("mock", null, null)
            is ModelConfig.OnDevice -> Triple("on_device", null, modelConfig.template)
            is ModelConfig.DeepSeek -> Triple("deepseek", modelConfig.apiKey, modelConfig.modelName)
            is ModelConfig.Nvidia -> Triple("nvidia", modelConfig.apiKey, modelConfig.modelName)
            is ModelConfig.Cloud -> Triple(modelConfig.provider, modelConfig.apiKey, modelConfig.modelName)
        }

        val modeStr = operatingMode.name.lowercase()

        try {
            val response = bridge.runAgentLoop(
                agentName = agentName,
                goal = goal,
                inputs = inputs,
                maxSteps = maxSteps,
                modelProvider = provider,
                modelApiKey = apiKey,
                modelName = modelName,
                operatingMode = modeStr
            )

            val duration = System.currentTimeMillis() - startTime
            val error = response["error"] as? String

            if (error != null) {
                val ex = IllegalStateException(error)
                _agentState.value = AgentState.Failed(agentName, goal, error, ex)
                Result.failure(ex)
            } else {
                val resultText = response["result"]?.toString() ?: ""
                @Suppress("UNCHECKED_CAST")
                val trace = (response["trace"] as? List<Map<String, Any?>>) ?: emptyList()
                val stepCount = (response["stepCount"] as? Number)?.toInt() ?: 1
                @Suppress("UNCHECKED_CAST")
                val state = (response["state"] as? Map<String, Any?>) ?: emptyMap()
                @Suppress("UNCHECKED_CAST")
                val heapHandles = (response["heapHandles"] as? List<String>) ?: emptyList()

                val executionResult = AgentExecutionResult(
                    agentName = agentName,
                    goal = goal,
                    resultText = resultText,
                    isSuccess = true,
                    stepCount = stepCount,
                    durationMs = duration,
                    trace = trace,
                    state = state,
                    heapHandles = heapHandles
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
            val agents = response["agents"] as? List<String>
            if (agents != null) {
                Result.success(agents)
            } else {
                val error = response["error"]?.toString() ?: "Failed to list registered agents"
                Result.failure(IllegalStateException(error))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun replaySession(sessionId: String, stepIndex: Int): Result<Map<String, Any?>> =
        withContext(Dispatchers.Default) {
            try {
                val response = bridge.replaySession(sessionId, stepIndex)
                val error = response["error"] as? String
                if (error != null) {
                    Result.failure(IllegalStateException(error))
                } else {
                    Result.success(response)
                }
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    override suspend fun forkSession(
        sessionId: String,
        newSessionId: String,
        fromStepIndex: Int
    ): Result<Map<String, Any?>> = withContext(Dispatchers.Default) {
        try {
            val response = bridge.forkSession(sessionId, newSessionId, fromStepIndex)
            val error = response["error"] as? String
            if (error != null) {
                Result.failure(IllegalStateException(error))
            } else {
                Result.success(response)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun getHardwareTelemetry(): Result<HardwareTelemetry> = withContext(Dispatchers.Default) {
        try {
            val battery = bridge.deviceHarness.getBatteryInfo()
            val memory = bridge.deviceHarness.getMemoryInfo()
            val thermals = bridge.deviceHarness.getThermalStatus()
            val network = bridge.deviceHarness.getNetworkStatus()

            val batteryLevel = (battery["batteryLevel"] as? Number)?.toFloat() ?: 1.0f
            val isCharging = (battery["isCharging"] as? Boolean) ?: false
            val availRam = (memory["availableRamMb"] as? Number)?.toInt() ?: 4096
            val totalRam = (memory["totalRamMb"] as? Number)?.toInt() ?: 8192
            val isLowRam = (memory["isLowRamDevice"] as? Boolean) ?: false

            Result.success(
                HardwareTelemetry(
                    batteryLevel = batteryLevel,
                    isCharging = isCharging,
                    availableRamMb = availRam,
                    totalRamMb = totalRam,
                    thermalStatus = thermals,
                    networkStatus = network,
                    isLowRam = isLowRam
                )
            )
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun assessGovernorBudget(): Result<GovernorBudget> = withContext(Dispatchers.Default) {
        try {
            val telemetry = getHardwareTelemetry().getOrThrow()
            val isHot = telemetry.thermalStatus in listOf("serious", "severe", "critical", "emergency")
            val isLowMem = telemetry.availableRamMb < 500

            val budget = when {
                isHot -> GovernorBudget(
                    maxConcurrency = 1,
                    recommendedTier = "cloud_offload",
                    stepDelayMs = 500L,
                    isCloudOffloadRecommended = true
                )
                isLowMem -> GovernorBudget(
                    maxConcurrency = 1,
                    recommendedTier = "tiny_on_device",
                    stepDelayMs = 200L,
                    isCloudOffloadRecommended = false
                )
                telemetry.batteryLevel < 0.15f && !telemetry.isCharging -> GovernorBudget(
                    maxConcurrency = 2,
                    recommendedTier = "eco_on_device",
                    stepDelayMs = 100L,
                    isCloudOffloadRecommended = false
                )
                else -> GovernorBudget(
                    maxConcurrency = 4,
                    recommendedTier = "on_device_standard",
                    stepDelayMs = 0L,
                    isCloudOffloadRecommended = false
                )
            }
            Result.success(budget)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun listPlugins(): Result<List<PluginInfo>> = withContext(Dispatchers.Default) {
        try {
            val response = bridge.listPlugins()
            @Suppress("UNCHECKED_CAST")
            val pluginList = (response["plugins"] as? List<Map<String, Any?>>) ?: emptyList()
            val plugins = pluginList.map { p ->
                @Suppress("UNCHECKED_CAST")
                PluginInfo(
                    name = p["name"]?.toString() ?: "Unnamed Plugin",
                    version = p["version"]?.toString() ?: "1.0.0",
                    description = p["description"]?.toString() ?: "",
                    providedTools = (p["providedTools"] as? List<String>) ?: emptyList()
                )
            }
            Result.success(plugins)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override fun resetState() {
        _agentState.value = AgentState.Idle
    }
}
