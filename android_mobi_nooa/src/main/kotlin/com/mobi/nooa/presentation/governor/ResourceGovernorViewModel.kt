package com.mobi.nooa.presentation.governor

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mobi.nooa.domain.GovernorBudget
import com.mobi.nooa.domain.HardwareTelemetry
import com.mobi.nooa.domain.usecases.AssessGovernorBudgetUseCase
import com.mobi.nooa.domain.usecases.GetDeviceTelemetryUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * UI State for the Resource Governor & Hardware Monitor screen.
 */
data class ResourceGovernorUiState(
    val telemetry: HardwareTelemetry? = null,
    val budget: GovernorBudget? = null,
    val isCompactingHeap: Boolean = false,
    val isAutoOffloadActive: Boolean = false,
    val errorMessage: String? = null
)

/**
 * ViewModel managing hardware telemetry observation, RAM pressure, thermal throttling,
 * and adaptive concurrency load balancing.
 */
class ResourceGovernorViewModel(
    private val getDeviceTelemetryUseCase: GetDeviceTelemetryUseCase,
    private val assessGovernorBudgetUseCase: AssessGovernorBudgetUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(ResourceGovernorUiState())
    val uiState: StateFlow<ResourceGovernorUiState> = _uiState.asStateFlow()

    init {
        refreshGovernorState()
    }

    fun refreshGovernorState() {
        viewModelScope.launch {
            val telemetryResult = getDeviceTelemetryUseCase()
            val budgetResult = assessGovernorBudgetUseCase()

            _uiState.update { state ->
                state.copy(
                    telemetry = telemetryResult.getOrNull(),
                    budget = budgetResult.getOrNull(),
                    isAutoOffloadActive = budgetResult.getOrNull()?.isCloudOffloadRecommended ?: false,
                    errorMessage = telemetryResult.exceptionOrNull()?.message ?: budgetResult.exceptionOrNull()?.message
                )
            }
        }
    }

    fun compactHeap() {
        viewModelScope.launch {
            _uiState.update { it.copy(isCompactingHeap = true) }
            // Trigger GC & compact local SQLite/heap caches
            System.gc()
            _uiState.update { it.copy(isCompactingHeap = false) }
            refreshGovernorState()
        }
    }
}
