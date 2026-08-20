package com.mobi.nooa.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.ModelConfig
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Android Architecture ViewModel for binding autonomous agent lifecycle and execution
 * directly to Jetpack Compose or Fragment / Activity UI.
 */
class AgentViewModel(
    private val repository: AgentRepository
) : ViewModel() {

    /** Observable StateFlow for Compose UI state collection. */
    val agentState: StateFlow<AgentState> = repository.agentState

    /**
     * Triggers an agent loop in the ViewModel's structured coroutine scope.
     */
    fun executeTask(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?> = emptyMap(),
        maxSteps: Int = 10,
        modelConfig: ModelConfig = ModelConfig.Mock,
        onCompletion: ((Result<AgentExecutionResult>) -> Unit)? = null
    ) {
        viewModelScope.launch {
            val result = repository.executeAgent(
                agentName = agentName,
                goal = goal,
                inputs = inputs,
                maxSteps = maxSteps,
                modelConfig = modelConfig
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
