package com.mobi.nooa.domain.usecases

import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.PluginInfo

/**
 * Domain Use Case to list and inspect active dynamic plugins and service seams.
 */
class ManagePluginsUseCase(
    private val repository: AgentRepository
) {
    suspend fun listPlugins(): Result<List<PluginInfo>> {
        return repository.listPlugins()
    }
}
