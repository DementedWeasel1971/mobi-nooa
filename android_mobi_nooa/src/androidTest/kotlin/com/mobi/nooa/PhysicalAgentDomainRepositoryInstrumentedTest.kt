package com.mobi.nooa

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.mobi.nooa.data.DefaultAgentRepository
import com.mobi.nooa.domain.AgentState
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * On-Device Agent Domain & Repository Instrumented Test Suite.
 * Validates Kotlin Clean Architecture, StateFlow reactivity, and Coroutines execution
 * directly on real device dispatchers.
 */
@RunWith(AndroidJUnit4::class)
class PhysicalAgentDomainRepositoryInstrumentedTest {

    private lateinit var context: Context
    private lateinit var bridge: MobiNooaBridge
    private lateinit var repository: DefaultAgentRepository

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        // FlutterEngine must be initialized on the Android UI/Main Thread
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            bridge = MobiNooaBridge.getInstance(context)
            repository = DefaultAgentRepository(bridge)
        }
    }

    @Test
    fun testPhysicalRepositoryInitialState() = runBlocking {
        val initialState = repository.agentState.first()
        assertNotNull("Initial state must not be null", initialState)
        assertTrue("Initial state must be Idle", initialState is AgentState.Idle)
    }
}
