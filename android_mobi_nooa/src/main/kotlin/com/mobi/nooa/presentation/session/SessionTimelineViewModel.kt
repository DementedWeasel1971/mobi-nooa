package com.mobi.nooa.presentation.session

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mobi.nooa.domain.usecases.ManageSessionUseCase
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * UI State for the Session Time-Travel & Forking screen.
 */
data class SessionTimelineUiState(
    val currentSessionId: String = "session_01",
    val totalSteps: Int = 5,
    val selectedStepIndex: Int = 0,
    val reconstructedState: Map<String, Any?> = emptyMap(),
    val forkedSessionId: String? = null,
    val isScrubbing: Boolean = false,
    val errorMessage: String? = null
)

/**
 * ViewModel managing time-travel state reconstruction and branch forking.
 */
class SessionTimelineViewModel(
    private val manageSessionUseCase: ManageSessionUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(SessionTimelineUiState())
    val uiState: StateFlow<SessionTimelineUiState> = _uiState.asStateFlow()

    fun scrubToStep(sessionId: String, stepIndex: Int) {
        _uiState.update { it.copy(currentSessionId = sessionId, selectedStepIndex = stepIndex, isScrubbing = true) }

        viewModelScope.launch {
            manageSessionUseCase.replayState(sessionId, stepIndex)
                .onSuccess { state ->
                    _uiState.update {
                        it.copy(
                            isScrubbing = false,
                            reconstructedState = state,
                            errorMessage = null
                        )
                    }
                }
                .onFailure { err ->
                    _uiState.update {
                        it.copy(
                            isScrubbing = false,
                            errorMessage = err.message
                        )
                    }
                }
        }
    }

    fun forkBranch(sessionId: String, newSessionId: String, fromStepIndex: Int) {
        viewModelScope.launch {
            manageSessionUseCase.forkBranch(sessionId, newSessionId, fromStepIndex)
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            forkedSessionId = newSessionId,
                            currentSessionId = newSessionId,
                            errorMessage = null
                        )
                    }
                }
                .onFailure { err ->
                    _uiState.update { it.copy(errorMessage = err.message) }
                }
        }
    }
}
