package com.mobi.nooa.domain.usecases

import com.mobi.nooa.domain.AgentInfo
import com.mobi.nooa.domain.AgentRepository

/**
 * Domain Use Case to retrieve available reference agents and their capability metadata.
 */
class ListRegisteredAgentsUseCase(
    private val repository: AgentRepository
) {
    suspend operator fun invoke(): Result<List<AgentInfo>> {
        return repository.listRegisteredAgents().map { agentNames ->
            agentNames.map { name ->
                when (name) {
                    "AutonomousDeviceAgent" -> AgentInfo(
                        name = name,
                        role = "System & Hardware Triage",
                        description = "Monitors hardware telemetry, battery, notifications, and synthesizes procedural skills."
                    )
                    "DataAnalystAgent" -> AgentInfo(
                        name = name,
                        role = "Pass-by-Reference Data Science",
                        description = "Manipulates large datasets via ObjectHeap #ref handles and on-device SQLite queries."
                    )
                    "AutonomousCodingAgent" -> AgentInfo(
                        name = name,
                        role = "Software Engineering & Refactoring",
                        description = "Inspects line-numbered files, performs exact strReplace edits, and executes safe shell commands."
                    )
                    "BenchAgent" -> AgentInfo(
                        name = name,
                        role = "Benchmark Evaluation",
                        description = "NVIDIA official port for SWE-bench Verified and CyberGym benchmarks."
                    )
                    else -> AgentInfo(
                        name = name,
                        role = "General Mobile Assistant",
                        description = "Lightweight baseline assistant for simple mobile tasks."
                    )
                }
            }
        }
    }
}
