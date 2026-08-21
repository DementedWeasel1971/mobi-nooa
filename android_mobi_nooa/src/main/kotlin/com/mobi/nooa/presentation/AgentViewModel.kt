package com.mobi.nooa.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentInfo
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.HardwareTelemetry
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.domain.usecases.ExecuteAgentTaskUseCase
import com.mobi.nooa.domain.usecases.GetDeviceTelemetryUseCase
import com.mobi.nooa.domain.usecases.ListRegisteredAgentsUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Android Architecture ViewModel for binding autonomous agent lifecycle and execution
 * directly to Jetpack Compose or Fragment / Activity UI.
 * Follows Google Android UDF (Unidirectional Data Flow) & Clean Architecture.
 */
class AgentViewModel(
    private val executeAgentTaskUseCase: ExecuteAgentTaskUseCase,
    private val listRegisteredAgentsUseCase: ListRegisteredAgentsUseCase,
    private val getDeviceTelemetryUseCase: GetDeviceTelemetryUseCase,
    private val repository: AgentRepository
) : ViewModel() {

    /** Observable StateFlow for Compose UI state collection. */
    val agentState: StateFlow<AgentState> = repository.agentState

    private val _availableAgents = MutableStateFlow<List<AgentInfo>>(emptyList())
    val availableAgents: StateFlow<List<AgentInfo>> = _availableAgents.asStateFlow()

    private val _telemetry = MutableStateFlow<HardwareTelemetry?>(null)
    val telemetry: StateFlow<HardwareTelemetry?> = _telemetry.asStateFlow()

    init {
        loadAgents()
        refreshTelemetry()
    }

    /**
     * Loads registered reference agents from the engine.
     */
    fun loadAgents() {
        viewModelScope.launch {
            listRegisteredAgentsUseCase().onSuccess { agents ->
                _availableAgents.value = agents
            }
        }
    }

    /**
     * Refreshes hardware telemetry metrics.
     */
    fun refreshTelemetry() {
        viewModelScope.launch {
            getDeviceTelemetryUseCase().onSuccess { t ->
                _telemetry.value = t
            }
        }
    }

    /**
     * Triggers an agent loop in the ViewModel's structured coroutine scope.
     */
    fun executeTask(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?> = emptyMap(),
        maxSteps: Int = 10,
        modelConfig: ModelConfig = ModelConfig.Mock,
        operatingMode: AgentOperatingMode = AgentOperatingMode.AUTONOMOUS,
        onCompletion: ((Result<AgentExecutionResult>) -> Unit)? = null
    ) {
        viewModelScope.launch {
            val result = executeAgentTaskUseCase(
                agentName = agentName,
                goal = goal,
                inputs = inputs,
                maxSteps = maxSteps,
                modelConfig = modelConfig,
                operatingMode = operatingMode
            )
            onCompletion?.invoke(result)
        }
    }

    /**
     * Resets current UI state back to idle.
     */
    fun reset() {
        repository.resetState()
    }
}
