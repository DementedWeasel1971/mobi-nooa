package com.mobi.nooa.di

import android.content.Context
import com.mobi.nooa.MobiNooaBridge
import com.mobi.nooa.data.DefaultAgentRepository
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.usecases.AssessGovernorBudgetUseCase
import com.mobi.nooa.domain.usecases.ExecuteAgentTaskUseCase
import com.mobi.nooa.domain.usecases.GetDeviceTelemetryUseCase
import com.mobi.nooa.domain.usecases.ListRegisteredAgentsUseCase
import com.mobi.nooa.domain.usecases.ManagePluginsUseCase
import com.mobi.nooa.domain.usecases.ManageSessionUseCase

/**
 * Lightweight Service Locator & Dependency Container following Kotlin best practices
 * for clean architecture without forcing heavyweight framework dependencies.
 */
class MobiNooaContainer(context: Context) {

    val bridge: MobiNooaBridge by lazy {
        MobiNooaBridge.getInstance(context.applicationContext)
    }

    val agentRepository: AgentRepository by lazy {
        DefaultAgentRepository(bridge)
    }

    val executeAgentTaskUseCase: ExecuteAgentTaskUseCase by lazy {
        ExecuteAgentTaskUseCase(agentRepository)
    }

    val listRegisteredAgentsUseCase: ListRegisteredAgentsUseCase by lazy {
        ListRegisteredAgentsUseCase(agentRepository)
    }

    val getDeviceTelemetryUseCase: GetDeviceTelemetryUseCase by lazy {
        GetDeviceTelemetryUseCase(agentRepository)
    }

    val manageSessionUseCase: ManageSessionUseCase by lazy {
        ManageSessionUseCase(agentRepository)
    }

    val managePluginsUseCase: ManagePluginsUseCase by lazy {
        ManagePluginsUseCase(agentRepository)
    }

    val assessGovernorBudgetUseCase: AssessGovernorBudgetUseCase by lazy {
        AssessGovernorBudgetUseCase(agentRepository)
    }
}
