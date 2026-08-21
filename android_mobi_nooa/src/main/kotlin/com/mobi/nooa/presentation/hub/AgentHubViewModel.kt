package com.mobi.nooa.presentation.hub

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mobi.nooa.domain.AgentInfo
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.HardwareTelemetry
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.domain.usecases.GetDeviceTelemetryUseCase
import com.mobi.nooa.domain.usecases.ListRegisteredAgentsUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * UI State for the Agent Hub & Mobile Dashboard.
 */
data class AgentHubUiState(
    val agents: List<AgentInfo> = emptyList(),
    val selectedAgent: AgentInfo? = null,
    val selectedMode: AgentOperatingMode = AgentOperatingMode.AUTONOMOUS,
    val selectedModel: ModelConfig = ModelConfig.DeepSeek("deepseek-reasoner", null),
    val telemetry: HardwareTelemetry? = null,
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

/**
 * Android ViewModel managing the Agent Hub Screen state, model configurations,
 * and hardware health chips.
 */
class AgentHubViewModel(
    private val listRegisteredAgentsUseCase: ListRegisteredAgentsUseCase,
    private val getDeviceTelemetryUseCase: GetDeviceTelemetryUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(AgentHubUiState())
    val uiState: StateFlow<AgentHubUiState> = _uiState.asStateFlow()

    init {
        loadDashboard()
    }

    fun loadDashboard() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }

            val agentsResult = listRegisteredAgentsUseCase()
            val telemetryResult = getDeviceTelemetryUseCase()

            _uiState.update { state ->
                state.copy(
                    isLoading = false,
                    agents = agentsResult.getOrDefault(emptyList()),
                    selectedAgent = agentsResult.getOrNull()?.firstOrNull(),
                    telemetry = telemetryResult.getOrNull(),
                    errorMessage = agentsResult.exceptionOrNull()?.message
                )
            }
        }
    }

    fun selectAgent(agent: AgentInfo) {
        _uiState.update { it.copy(selectedAgent = agent) }
    }

    fun selectMode(mode: AgentOperatingMode) {
        _uiState.update { it.copy(selectedMode = mode) }
    }

    fun selectModel(model: ModelConfig) {
        _uiState.update { it.copy(selectedModel = model) }
    }
}
