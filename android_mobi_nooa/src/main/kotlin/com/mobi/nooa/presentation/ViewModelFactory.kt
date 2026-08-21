package com.mobi.nooa.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.mobi.nooa.di.MobiNooaContainer
import com.mobi.nooa.presentation.execution.AgentExecutionViewModel
import com.mobi.nooa.presentation.governor.ResourceGovernorViewModel
import com.mobi.nooa.presentation.hub.AgentHubViewModel
import com.mobi.nooa.presentation.session.SessionTimelineViewModel

/**
 * Custom [ViewModelProvider.Factory] to instantiate ViewModels with clean architecture use cases.
 */
class MobiNooaViewModelFactory(
    private val container: MobiNooaContainer
) : ViewModelProvider.Factory {

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return when {
            modelClass.isAssignableFrom(AgentViewModel::class.java) -> {
                AgentViewModel(
                    executeAgentTaskUseCase = container.executeAgentTaskUseCase,
                    listRegisteredAgentsUseCase = container.listRegisteredAgentsUseCase,
                    getDeviceTelemetryUseCase = container.getDeviceTelemetryUseCase,
                    repository = container.agentRepository
                ) as T
            }
            modelClass.isAssignableFrom(AgentHubViewModel::class.java) -> {
                AgentHubViewModel(
                    listRegisteredAgentsUseCase = container.listRegisteredAgentsUseCase,
                    getDeviceTelemetryUseCase = container.getDeviceTelemetryUseCase
                ) as T
            }
            modelClass.isAssignableFrom(AgentExecutionViewModel::class.java) -> {
                AgentExecutionViewModel(
                    executeAgentTaskUseCase = container.executeAgentTaskUseCase,
                    repository = container.agentRepository
                ) as T
            }
            modelClass.isAssignableFrom(SessionTimelineViewModel::class.java) -> {
                SessionTimelineViewModel(
                    manageSessionUseCase = container.manageSessionUseCase
                ) as T
            }
            modelClass.isAssignableFrom(ResourceGovernorViewModel::class.java) -> {
                ResourceGovernorViewModel(
                    getDeviceTelemetryUseCase = container.getDeviceTelemetryUseCase,
                    assessGovernorBudgetUseCase = container.assessGovernorBudgetUseCase
                ) as T
            }
            else -> throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
        }
    }
}
