package com.mobi.nooa

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OnDeviceModelEngineTest {

    @Test
    fun testInferenceOptionsDefaultValues() {
        val options = InferenceOptions()
        assertEquals(0.2f, options.temperature, 0.001f)
        assertEquals(0.9f, options.topP, 0.001f)
        assertEquals(1024, options.maxTokens)
        assertEquals(4, options.threads)
        assertEquals(4096, options.contextLength)
        assertTrue(options.stopSequences.isEmpty())
    }

    @Test
    fun testLlamaCppEngineLifecycleAndUnloadedState() = runBlocking {
        val engine = LlamaCppInferenceEngine()
        assertEquals(InferenceBackend.LLAMA_CPP, engine.backend)
        assertFalse(engine.isLoaded)

        // Generating when unloaded should fail
        val result = engine.generate("test prompt")
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is IllegalStateException)
    }

    @Test
    fun testGenerationResultAndUsageCalculations() {
        val usage = LocalTokenUsage(
            promptTokens = 120,
            completionTokens = 80,
            totalTokens = 200
        )
        val result = GenerationResult(
            text = "Autonomous agent plan executed successfully.",
            finishReason = "stop",
            usage = usage,
            latencyMs = 150L
        )

        assertEquals("Autonomous agent plan executed successfully.", result.text)
        assertEquals("stop", result.finishReason)
        assertEquals(200, result.usage.totalTokens)
        assertEquals(150L, result.latencyMs)
    }
}
