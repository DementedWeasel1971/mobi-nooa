package com.mobi.nooa.domain.usecases

import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.HardwareTelemetry

/**
 * Domain Use Case to query live Android device telemetry.
 */
class GetDeviceTelemetryUseCase(
    private val repository: AgentRepository
) {
    suspend operator fun invoke(): Result<HardwareTelemetry> {
        return repository.getHardwareTelemetry()
    }
}
