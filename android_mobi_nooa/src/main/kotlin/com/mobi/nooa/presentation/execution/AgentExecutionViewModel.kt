package com.mobi.nooa.presentation.execution

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.domain.PermissionApprovalRequest
import com.mobi.nooa.domain.usecases.ExecuteAgentTaskUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * UI State for the Live Autonomous Agent Execution Stream.
 */
data class AgentExecutionUiState(
    val agentName: String = "",
    val goal: String = "",
    val currentStep: Int = 0,
    val maxSteps: Int = 10,
    val isRunning: Boolean = false,
    val reasoningThoughts: String? = null,
    val isThoughtExpanded: Boolean = true,
    val executionResult: AgentExecutionResult? = null,
    val heapHandles: List<String> = emptyList(),
    val selectedHeapHandle: String? = null,
    val permissionRequest: PermissionApprovalRequest? = null,
    val fallbackHistory: List<com.mobi.nooa.domain.ProviderFallbackEvent> = emptyList(),
    val activeFallbackWarning: String? = null,
    val errorMessage: String? = null
)

/**
 * ViewModel managing the active agent loop trajectory, DeepSeek thinking stream,
 * pass-by-reference handles, and mobile permission approvals.
 */
class AgentExecutionViewModel(
    private val executeAgentTaskUseCase: ExecuteAgentTaskUseCase,
    private val repository: AgentRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AgentExecutionUiState())
    val uiState: StateFlow<AgentExecutionUiState> = _uiState.asStateFlow()

    init {
        observeAgentState()
    }

    private fun observeAgentState() {
        viewModelScope.launch {
            repository.agentState.collect { state ->
                when (state) {
                    is AgentState.Idle -> {
                        _uiState.update { it.copy(isRunning = false) }
                    }
                    is AgentState.Running -> {
                        _uiState.update {
                            it.copy(
                                isRunning = true,
                                agentName = state.agentName,
                                goal = state.goal,
                                currentStep = state.currentStep,
                                maxSteps = state.maxSteps,
                                reasoningThoughts = state.reasoningContent ?: state.latestThought
                            )
                        }
                    }
                    is AgentState.Success -> {
                        val fallbackWarning = if (state.result.fallbackHistory.isNotEmpty()) {
                            val lastFallback = state.result.fallbackHistory.last()
                            "⚠️ Provider '${lastFallback.failedProvider}' failed. Recovered on fallback '${lastFallback.fallbackProvider ?: "secondary"}'."
                        } else null

                        _uiState.update {
                            it.copy(
                                isRunning = false,
                                executionResult = state.result,
                                heapHandles = state.result.heapHandles,
                                currentStep = state.result.stepCount,
                                fallbackHistory = state.result.fallbackHistory,
                                activeFallbackWarning = fallbackWarning
                            )
                        }
                    }
                    is AgentState.Failed -> {
                        _uiState.update {
                            it.copy(
                                isRunning = false,
                                errorMessage = state.error
                            )
                        }
                    }
                }
            }
        }
    }

    fun startTask(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?> = emptyMap(),
        maxSteps: Int = 10,
        modelConfig: ModelConfig = ModelConfig.DeepSeek("deepseek-reasoner", null),
        operatingMode: AgentOperatingMode = AgentOperatingMode.AUTONOMOUS
    ) {
        _uiState.update {
            it.copy(
                agentName = agentName,
                goal = goal,
                isRunning = true,
                errorMessage = null,
                executionResult = null
            )
        }

        viewModelScope.launch {
            executeAgentTaskUseCase(
                agentName = agentName,
                goal = goal,
                inputs = inputs,
                maxSteps = maxSteps,
                modelConfig = modelConfig,
                operatingMode = operatingMode
            )
        }
    }

    fun toggleThoughtExpansion() {
        _uiState.update { it.copy(isThoughtExpanded = !it.isThoughtExpanded) }
    }

    fun selectHeapHandle(handle: String?) {
        _uiState.update { it.copy(selectedHeapHandle = handle) }
    }

    fun respondToPermission(approved: Boolean) {
        _uiState.update { it.copy(permissionRequest = null) }
    }
}
