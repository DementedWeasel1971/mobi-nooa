package com.mobi.nooa

import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.ModelConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AgentDomainArchitectureTest {

    @Test
    fun testAgentExecutionResultCreation() {
        val result = AgentExecutionResult(
            agentName = "AutonomousDeviceAgent",
            goal = "Check battery and wifi",
            resultText = "Battery is 85%, WiFi is connected.",
            isSuccess = true,
            stepCount = 3,
            durationMs = 450L
        )

        assertEquals("AutonomousDeviceAgent", result.agentName)
        assertEquals("Check battery and wifi", result.goal)
        assertTrue(result.isSuccess)
        assertEquals(3, result.stepCount)
        assertEquals(450L, result.durationMs)
        assertNull(result.errorMessage)
    }

    @Test
    fun testAgentStateHierarchyAndTransitions() {
        val idleState: AgentState = AgentState.Idle
        assertTrue(idleState is AgentState.Idle)

        val runningState: AgentState = AgentState.Running(
            agentName = "DataAnalystAgent",
            goal = "Aggregate sensor logs",
            currentStep = 2,
            maxSteps = 5
        )
        assertTrue(runningState is AgentState.Running)
        val running = runningState as AgentState.Running
        assertEquals(2, running.currentStep)
        assertEquals(5, running.maxSteps)

        val successState: AgentState = AgentState.Success(
            AgentExecutionResult(
                agentName = "DataAnalystAgent",
                goal = "Aggregate sensor logs",
                resultText = "Summary completed",
                isSuccess = true
            )
        )
        assertTrue(successState is AgentState.Success)

        val failedState: AgentState = AgentState.Failed(
            agentName = "DataAnalystAgent",
            goal = "Aggregate sensor logs",
            error = "Out of memory"
        )
        assertTrue(failedState is AgentState.Failed)
        assertEquals("Out of memory", (failedState as AgentState.Failed).error)
    }

    @Test
    fun testModelConfigHierarchy() {
        val mockConfig = ModelConfig.Mock
        val onDeviceConfig = ModelConfig.OnDevice(template = "llama3")
        val cloudConfig = ModelConfig.Cloud(provider = "gemini", apiKey = "secret_key")

        assertEquals("llama3", onDeviceConfig.template)
        assertEquals("gemini", cloudConfig.provider)
        assertEquals("secret_key", cloudConfig.apiKey)
    }

    @Test
    fun testModelConfigCascadeAndFallbackEvents() {
        val primary = ModelConfig.DeepSeek(apiKey = "invalid_key")
        val secondary = ModelConfig.OnDevice(template = "llama3")
        val tertiary = ModelConfig.Mock

        val cascadeConfig = ModelConfig.Cascade(
            cascade = listOf(primary, secondary, tertiary),
            timeoutSeconds = 30,
            maxRetries = 2
        )

        assertEquals(3, cascadeConfig.cascade.size)
        assertEquals(30, cascadeConfig.timeoutSeconds)
        assertEquals(2, cascadeConfig.maxRetries)
        assertTrue(cascadeConfig.cascade[0] is ModelConfig.DeepSeek)
        assertTrue(cascadeConfig.cascade[1] is ModelConfig.OnDevice)
        assertTrue(cascadeConfig.cascade[2] is ModelConfig.Mock)

        val fallbackEvent = com.mobi.nooa.domain.ProviderFallbackEvent(
            type = "providerFallback",
            failedProvider = "deepseek-reasoner",
            fallbackProvider = "on_device",
            errorMessage = "HTTP 401 Unauthorized"
        )

        val resultWithFallback = AgentExecutionResult(
            agentName = "AutonomousDeviceAgent",
            goal = "Triage hardware",
            resultText = "Completed via on-device fallback",
            isSuccess = true,
            fallbackHistory = listOf(fallbackEvent)
        )

        assertEquals(1, resultWithFallback.fallbackHistory.size)
        assertEquals("deepseek-reasoner", resultWithFallback.fallbackHistory[0].failedProvider)
        assertEquals("on_device", resultWithFallback.fallbackHistory[0].fallbackProvider)
        assertEquals("HTTP 401 Unauthorized", resultWithFallback.fallbackHistory[0].errorMessage)
    }
}
