package com.mobi.nooa.domain.usecases

import com.mobi.nooa.domain.AgentRepository

/**
 * Domain Use Case to perform Time-Travel Replay and Branch Forking on historical sessions.
 */
class ManageSessionUseCase(
    private val repository: AgentRepository
) {
    suspend fun replayState(sessionId: String, stepIndex: Int): Result<Map<String, Any?>> {
        if (sessionId.isBlank()) {
            return Result.failure(IllegalArgumentException("Session ID cannot be blank."))
        }
        if (stepIndex < 0) {
            return Result.failure(IllegalArgumentException("Step index must be non-negative."))
        }
        return repository.replaySession(sessionId, stepIndex)
    }

    suspend fun forkBranch(sessionId: String, newSessionId: String, fromStepIndex: Int): Result<Map<String, Any?>> {
        if (sessionId.isBlank() || newSessionId.isBlank()) {
            return Result.failure(IllegalArgumentException("Session IDs cannot be blank."))
        }
        if (fromStepIndex < 0) {
            return Result.failure(IllegalArgumentException("From step index must be non-negative."))
        }
        return repository.forkSession(sessionId, newSessionId, fromStepIndex)
    }
}
