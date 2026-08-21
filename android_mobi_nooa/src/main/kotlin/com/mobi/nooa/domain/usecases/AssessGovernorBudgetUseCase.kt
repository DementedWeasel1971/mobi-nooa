package com.mobi.nooa.domain.usecases

import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.GovernorBudget

/**
 * Domain Use Case to evaluate on-device resource constraints and compute execution budget.
 */
class AssessGovernorBudgetUseCase(
    private val repository: AgentRepository
) {
    suspend operator fun invoke(): Result<GovernorBudget> {
        return repository.assessGovernorBudget()
    }
}
