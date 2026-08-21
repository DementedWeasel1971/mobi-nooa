package com.mobi.nooa

import com.mobi.nooa.domain.AgentExecutionResult
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentRepository
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.GovernorBudget
import com.mobi.nooa.domain.HardwareTelemetry
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.domain.PluginInfo
import com.mobi.nooa.domain.usecases.AssessGovernorBudgetUseCase
import com.mobi.nooa.domain.usecases.ExecuteAgentTaskUseCase
import com.mobi.nooa.domain.usecases.GetDeviceTelemetryUseCase
import com.mobi.nooa.domain.usecases.ListRegisteredAgentsUseCase
import com.mobi.nooa.domain.usecases.ManagePluginsUseCase
import com.mobi.nooa.domain.usecases.ManageSessionUseCase
import com.mobi.nooa.presentation.AgentViewModel
import com.mobi.nooa.presentation.execution.AgentExecutionViewModel
import com.mobi.nooa.presentation.governor.ResourceGovernorViewModel
import com.mobi.nooa.presentation.hub.AgentHubViewModel
import com.mobi.nooa.presentation.session.SessionTimelineViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Fake in-memory implementation of [AgentRepository] for fast deterministic unit tests.
 */
class FakeAgentRepository : AgentRepository {
    private val _agentState = MutableStateFlow<AgentState>(AgentState.Idle)
    override val agentState: StateFlow<AgentState> = _agentState

    var shouldFail = false
    var lastExecutedAgent: String? = null
    var lastGoal: String? = null
    var lastOperatingMode: AgentOperatingMode? = null

    override suspend fun executeAgent(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?>,
        maxSteps: Int,
        modelConfig: ModelConfig,
        operatingMode: AgentOperatingMode
    ): Result<AgentExecutionResult> {
        lastExecutedAgent = agentName
        lastGoal = goal
        lastOperatingMode = operatingMode

        _agentState.value = AgentState.Running(
            agentName = agentName,
            goal = goal,
            currentStep = 1,
            maxSteps = maxSteps,
            reasoningContent = "Analyzing system parameters..."
        )

        return if (shouldFail) {
            val ex = IllegalStateException("Simulated execution failure")
            _agentState.value = AgentState.Failed(agentName, goal, ex.message ?: "Failed", ex)
            Result.failure(ex)
        } else {
            val result = AgentExecutionResult(
                agentName = agentName,
                goal = goal,
                resultText = "Task completed successfully for $goal",
                isSuccess = true,
                stepCount = 3,
                durationMs = 120L,
                state = mapOf("status" to "nominal"),
                heapHandles = listOf("#ref_data_01")
            )
            _agentState.value = AgentState.Success(result)
            Result.success(result)
        }
    }

    override suspend fun listRegisteredAgents(): Result<List<String>> {
        return Result.success(
            listOf(
                "AutonomousDeviceAgent",
                "DataAnalystAgent",
                "AutonomousCodingAgent",
                "BenchAgent",
                "GeneralMobileAgent"
            )
        )
    }

    override suspend fun replaySession(sessionId: String, stepIndex: Int): Result<Map<String, Any?>> {
        return Result.success(mapOf("sessionId" to sessionId, "stepIndex" to stepIndex, "batteryDrain" to "1.2%/hr"))
    }

    override suspend fun forkSession(
        sessionId: String,
        newSessionId: String,
        fromStepIndex: Int
    ): Result<Map<String, Any?>> {
        return Result.success(mapOf("sessionId" to newSessionId, "forkedFrom" to sessionId, "stepIndex" to fromStepIndex))
    }

    override suspend fun getHardwareTelemetry(): Result<HardwareTelemetry> {
        return Result.success(
            HardwareTelemetry(
                batteryLevel = 0.85f,
                isCharging = false,
                availableRamMb = 3200,
                totalRamMb = 8192,
                thermalStatus = "nominal",
                networkStatus = "wifi"
            )
        )
    }

    override suspend fun assessGovernorBudget(): Result<GovernorBudget> {
        return Result.success(
            GovernorBudget(
                maxConcurrency = 4,
                recommendedTier = "on_device_standard",
                stepDelayMs = 0L,
                isCloudOffloadRecommended = false
            )
        )
    }

    override suspend fun listPlugins(): Result<List<PluginInfo>> {
        return Result.success(
            listOf(
                PluginInfo(
                    name = "TelemetryLoggerPlugin",
                    version = "1.0.0",
                    description = "Captures structured events",
                    providedTools = emptyList()
                ),
                PluginInfo(
                    name = "DynamicToolPlugin",
                    version = "1.0.0",
                    description = "Dynamic lambda tools",
                    providedTools = listOf("computeFactorial")
                )
            )
        )
    }

    override fun resetState() {
        _agentState.value = AgentState.Idle
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class CleanArchitectureUseCaseTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var repository: FakeAgentRepository
    private lateinit var executeUseCase: ExecuteAgentTaskUseCase
    private lateinit var listAgentsUseCase: ListRegisteredAgentsUseCase
    private lateinit var getTelemetryUseCase: GetDeviceTelemetryUseCase
    private lateinit var manageSessionUseCase: ManageSessionUseCase
    private lateinit var managePluginsUseCase: ManagePluginsUseCase
    private lateinit var assessBudgetUseCase: AssessGovernorBudgetUseCase

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        repository = FakeAgentRepository()
        executeUseCase = ExecuteAgentTaskUseCase(repository)
        listAgentsUseCase = ListRegisteredAgentsUseCase(repository)
        getTelemetryUseCase = GetDeviceTelemetryUseCase(repository)
        manageSessionUseCase = ManageSessionUseCase(repository)
        managePluginsUseCase = ManagePluginsUseCase(repository)
        assessBudgetUseCase = AssessGovernorBudgetUseCase(repository)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testExecuteAgentTaskUseCase_Success() = runTest {
        val result = executeUseCase(
            agentName = "AutonomousDeviceAgent",
            goal = "Triage battery",
            maxSteps = 5,
            modelConfig = ModelConfig.DeepSeek("deepseek-reasoner", "sk-test"),
            operatingMode = AgentOperatingMode.AUTONOMOUS
        )

        assertTrue(result.isSuccess)
        val exec = result.getOrNull()
        assertNotNull(exec)
        assertEquals("AutonomousDeviceAgent", exec?.agentName)
        assertEquals(3, exec?.stepCount)
        assertEquals(AgentOperatingMode.AUTONOMOUS, repository.lastOperatingMode)
    }

    @Test
    fun testExecuteAgentTaskUseCase_BlankValidation() = runTest {
        val emptyAgent = executeUseCase(agentName = "", goal = "Do something")
        assertTrue(emptyAgent.isFailure)

        val emptyGoal = executeUseCase(agentName = "Agent", goal = "")
        assertTrue(emptyGoal.isFailure)
    }

    @Test
    fun testListRegisteredAgentsUseCase_MapsRichMetadata() = runTest {
        val result = listAgentsUseCase()
        assertTrue(result.isSuccess)
        val agents = result.getOrNull()!!
        assertEquals(5, agents.size)

        val deviceAgent = agents.find { it.name == "AutonomousDeviceAgent" }
        assertNotNull(deviceAgent)
        assertEquals("System & Hardware Triage", deviceAgent?.role)
    }

    @Test
    fun testManageSessionUseCase_ReplayAndFork() = runTest {
        val replay = manageSessionUseCase.replayState("session_01", 2)
        assertTrue(replay.isSuccess)
        assertEquals("1.2%/hr", replay.getOrNull()?.get("batteryDrain"))

        val fork = manageSessionUseCase.forkBranch("session_01", "session_01_exp", 2)
        assertTrue(fork.isSuccess)
        assertEquals("session_01_exp", fork.getOrNull()?.get("sessionId"))
    }

    @Test
    fun testAssessGovernorBudgetUseCase_ReturnsBudget() = runTest {
        val budget = assessBudgetUseCase()
        assertTrue(budget.isSuccess)
        assertEquals(4, budget.getOrNull()?.maxConcurrency)
        assertFalse(budget.getOrNull()?.isCloudOffloadRecommended ?: true)
    }

    @Test
    fun testAgentHubViewModel_UDF_StateUpdates() = runTest(testDispatcher) {
        val viewModel = AgentHubViewModel(listAgentsUseCase, getTelemetryUseCase)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(5, state.agents.size)
        assertNotNull(state.selectedAgent)
        assertEquals(0.85f, state.telemetry?.batteryLevel)

        viewModel.selectMode(AgentOperatingMode.SUPERVISED)
        assertEquals(AgentOperatingMode.SUPERVISED, viewModel.uiState.value.selectedMode)
    }

    @Test
    fun testAgentExecutionViewModel_TracksReasoningAndSteps() = runTest(testDispatcher) {
        val viewModel = AgentExecutionViewModel(executeUseCase, repository)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.startTask(
            agentName = "AutonomousCodingAgent",
            goal = "Refactor code"
        )
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isRunning)
        assertNotNull(state.executionResult)
        assertEquals(1, state.heapHandles.size)
    }

    @Test
    fun testSessionTimelineViewModel_ScrubbingAndReplay() = runTest(testDispatcher) {
        val viewModel = SessionTimelineViewModel(manageSessionUseCase)

        viewModel.scrubToStep("session_alpha", 3)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals("session_alpha", state.currentSessionId)
        assertEquals(3, state.selectedStepIndex)
        assertEquals("1.2%/hr", state.reconstructedState["batteryDrain"])
    }

    @Test
    fun testResourceGovernorViewModel_TelemetryAndHeapCompaction() = runTest(testDispatcher) {
        val viewModel = ResourceGovernorViewModel(getTelemetryUseCase, assessBudgetUseCase)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertEquals(3200, state.telemetry?.availableRamMb)
        assertEquals(4, state.budget?.maxConcurrency)

        viewModel.compactHeap()
        testDispatcher.scheduler.advanceUntilIdle()
        assertFalse(viewModel.uiState.value.isCompactingHeap)
    }
}
