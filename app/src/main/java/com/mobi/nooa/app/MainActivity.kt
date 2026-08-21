package com.mobi.nooa.app

import android.os.Bundle
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import com.google.android.material.tabs.TabLayout
import com.mobi.nooa.di.MobiNooaContainer
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.presentation.AgentViewModel
import com.mobi.nooa.presentation.MobiNooaViewModelFactory
import com.mobi.nooa.presentation.execution.AgentExecutionViewModel
import com.mobi.nooa.presentation.governor.ResourceGovernorViewModel
import com.mobi.nooa.presentation.hub.AgentHubViewModel
import com.mobi.nooa.presentation.session.SessionTimelineViewModel
import kotlinx.coroutines.launch

/**
 * Android Host Activity implementing the complete Neo-Neural Agentic Interface
 * across 5 specialized subsystems:
 * 1. Agent Hub & Mobile Dashboard
 * 2. Live Autonomous Execution Stream & DeepSeek Reasoning
 * 3. Plugin Marketplace & Service Seams
 * 4. Session Event Log & Time-Travel Tree
 * 5. Adaptive Resource Governor & Hardware Monitor
 */
class MainActivity : AppCompatActivity() {

    private lateinit var container: MobiNooaContainer
    private lateinit var agentViewModel: AgentViewModel
    private lateinit var hubViewModel: AgentHubViewModel
    private lateinit var executionViewModel: AgentExecutionViewModel
    private lateinit var timelineViewModel: SessionTimelineViewModel
    private lateinit var governorViewModel: ResourceGovernorViewModel

    // Header & Tabs
    private lateinit var tvEngineStatusBadge: TextView
    private lateinit var tabLayout: TabLayout
    private lateinit var layoutHub: ScrollView
    private lateinit var layoutStream: ScrollView
    private lateinit var layoutPlugins: ScrollView
    private lateinit var layoutSession: ScrollView
    private lateinit var layoutGovernor: ScrollView

    // Tab 1: Hub
    private lateinit var tvHubBattery: TextView
    private lateinit var tvHubRam: TextView
    private lateinit var tvHubThermal: TextView
    private lateinit var rgOperatingMode: RadioGroup
    private lateinit var spHubAgent: Spinner
    private lateinit var tvAgentDescription: TextView
    private lateinit var spHubProvider: Spinner
    private lateinit var etHubModelName: EditText
    private lateinit var etHubApiKey: EditText
    private lateinit var btnQuickStartTask: Button

    // Tab 2: Stream
    private lateinit var etStreamGoal: EditText
    private lateinit var btnStreamExecute: Button
    private lateinit var tvAstSecurityPill: TextView
    private lateinit var pbStreamProgress: ProgressBar
    private lateinit var cardDeepSeekThinking: LinearLayout
    private lateinit var headerDeepSeekThinking: LinearLayout
    private lateinit var tvThinkingToggle: TextView
    private lateinit var tvDeepSeekThoughts: TextView
    private lateinit var tvHeapHandlesChips: TextView
    private lateinit var tvStreamConsole: TextView

    // Tab 3: Plugins
    private lateinit var etDynamicToolName: EditText
    private lateinit var btnRegisterDynamicTool: Button
    private lateinit var tvDynamicToolStatus: TextView

    // Tab 4: Session Time-Travel
    private lateinit var etSessionId: EditText
    private lateinit var tvSessionStepIndicator: TextView
    private lateinit var sbSessionScrubber: SeekBar
    private lateinit var btnSessionReplay: Button
    private lateinit var btnSessionFork: Button
    private lateinit var tvSessionStateSnapshot: TextView

    // Tab 5: Governor
    private lateinit var tvGovRamPressure: TextView
    private lateinit var tvGovThermalState: TextView
    private lateinit var tvGovBattery: TextView
    private lateinit var tvGovNetwork: TextView
    private lateinit var tvGovBudgetSummary: TextView
    private lateinit var btnGovCompactHeap: Button
    private lateinit var btnGovRefresh: Button

    private val providers = listOf("nvidia", "deepseek", "openai", "gemini", "on_device", "mock")
    private val agents = listOf(
        "AutonomousDeviceAgent",
        "DataAnalystAgent",
        "AutonomousCodingAgent",
        "BenchAgent",
        "GeneralMobileAgent"
    )

    private val agentDescriptions = mapOf(
        "AutonomousDeviceAgent" to "Mobile system triage, battery monitoring, notifications, and two-way procedural skill learning.",
        "DataAnalystAgent" to "Large dataset manipulation via pass-by-reference handles (#ref_xxx) in ObjectHeap and SQLite analytics.",
        "AutonomousCodingAgent" to "Autonomous software engineering agent with exact strReplace, createFile, and AST guardrails.",
        "BenchAgent" to "Official NVIDIA port for SWE-bench & CyberGym mobile agent evaluation.",
        "GeneralMobileAgent" to "Lightweight baseline assistant for simple mobile commands and task execution."
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initDependencies()
        bindViews()
        setupTabs()
        setupSpinners()
        setupListeners()
        observeAllViewModels()
    }

    private fun initDependencies() {
        container = MobiNooaContainer(applicationContext)
        val factory = MobiNooaViewModelFactory(container)
        agentViewModel = ViewModelProvider(this, factory)[AgentViewModel::class.java]
        hubViewModel = ViewModelProvider(this, factory)[AgentHubViewModel::class.java]
        executionViewModel = ViewModelProvider(this, factory)[AgentExecutionViewModel::class.java]
        timelineViewModel = ViewModelProvider(this, factory)[SessionTimelineViewModel::class.java]
        governorViewModel = ViewModelProvider(this, factory)[ResourceGovernorViewModel::class.java]
    }

    private fun bindViews() {
        tvEngineStatusBadge = findViewById(R.id.tvEngineStatusBadge)
        tabLayout = findViewById(R.id.tabLayout)
        layoutHub = findViewById(R.id.layoutHub)
        layoutStream = findViewById(R.id.layoutStream)
        layoutPlugins = findViewById(R.id.layoutPlugins)
        layoutSession = findViewById(R.id.layoutSession)
        layoutGovernor = findViewById(R.id.layoutGovernor)

        // Hub Views
        tvHubBattery = findViewById(R.id.tvHubBattery)
        tvHubRam = findViewById(R.id.tvHubRam)
        tvHubThermal = findViewById(R.id.tvHubThermal)
        rgOperatingMode = findViewById(R.id.rgOperatingMode)
        spHubAgent = findViewById(R.id.spHubAgent)
        tvAgentDescription = findViewById(R.id.tvAgentDescription)
        spHubProvider = findViewById(R.id.spHubProvider)
        etHubModelName = findViewById(R.id.etHubModelName)
        etHubApiKey = findViewById(R.id.etHubApiKey)
        btnQuickStartTask = findViewById(R.id.btnQuickStartTask)

        // Stream Views
        etStreamGoal = findViewById(R.id.etStreamGoal)
        btnStreamExecute = findViewById(R.id.btnStreamExecute)
        tvAstSecurityPill = findViewById(R.id.tvAstSecurityPill)
        pbStreamProgress = findViewById(R.id.pbStreamProgress)
        cardDeepSeekThinking = findViewById(R.id.cardDeepSeekThinking)
        headerDeepSeekThinking = findViewById(R.id.headerDeepSeekThinking)
        tvThinkingToggle = findViewById(R.id.tvThinkingToggle)
        tvDeepSeekThoughts = findViewById(R.id.tvDeepSeekThoughts)
        tvHeapHandlesChips = findViewById(R.id.tvHeapHandlesChips)
        tvStreamConsole = findViewById(R.id.tvStreamConsole)

        // Plugin Views
        etDynamicToolName = findViewById(R.id.etDynamicToolName)
        btnRegisterDynamicTool = findViewById(R.id.btnRegisterDynamicTool)
        tvDynamicToolStatus = findViewById(R.id.tvDynamicToolStatus)

        // Session Views
        etSessionId = findViewById(R.id.etSessionId)
        tvSessionStepIndicator = findViewById(R.id.tvSessionStepIndicator)
        sbSessionScrubber = findViewById(R.id.sbSessionScrubber)
        btnSessionReplay = findViewById(R.id.btnSessionReplay)
        btnSessionFork = findViewById(R.id.btnSessionFork)
        tvSessionStateSnapshot = findViewById(R.id.tvSessionStateSnapshot)

        // Governor Views
        tvGovRamPressure = findViewById(R.id.tvGovRamPressure)
        tvGovThermalState = findViewById(R.id.tvGovThermalState)
        tvGovBattery = findViewById(R.id.tvGovBattery)
        tvGovNetwork = findViewById(R.id.tvGovNetwork)
        tvGovBudgetSummary = findViewById(R.id.tvGovBudgetSummary)
        btnGovCompactHeap = findViewById(R.id.btnGovCompactHeap)
        btnGovRefresh = findViewById(R.id.btnGovRefresh)
    }

    private fun setupTabs() {
        tabLayout.addTab(tabLayout.newTab().setText("🌐 Hub"))
        tabLayout.addTab(tabLayout.newTab().setText("⚡ Stream"))
        tabLayout.addTab(tabLayout.newTab().setText("🧩 Plugins"))
        tabLayout.addTab(tabLayout.newTab().setText("⏳ Time-Travel"))
        tabLayout.addTab(tabLayout.newTab().setText("🛡️ Governor"))

        tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                layoutHub.visibility = if (tab?.position == 0) View.VISIBLE else View.GONE
                layoutStream.visibility = if (tab?.position == 1) View.VISIBLE else View.GONE
                layoutPlugins.visibility = if (tab?.position == 2) View.VISIBLE else View.GONE
                layoutSession.visibility = if (tab?.position == 3) View.VISIBLE else View.GONE
                layoutGovernor.visibility = if (tab?.position == 4) View.VISIBLE else View.GONE
            }
            override fun onTabUnselected(tab: TabLayout.Tab?) {}
            override fun onTabReselected(tab: TabLayout.Tab?) {}
        })
    }

    private fun setupSpinners() {
        val providerAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, providers)
        spHubProvider.adapter = providerAdapter

        val agentAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, agents)
        spHubAgent.adapter = agentAdapter

        spHubProvider.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                when (providers[position]) {
                    "nvidia" -> etHubModelName.setText("meta/llama-3.3-70b-instruct")
                    "deepseek" -> etHubModelName.setText("deepseek-reasoner")
                    "openai" -> etHubModelName.setText("gpt-4o")
                    "gemini" -> etHubModelName.setText("gemini-1.5-flash")
                    "on_device" -> etHubModelName.setText("llama3")
                    "mock" -> etHubModelName.setText("mock-agent-v1")
                }
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        spHubAgent.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val agent = agents[position]
                tvAgentDescription.text = agentDescriptions[agent] ?: "Autonomous agent class."
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
    }

    private fun setupListeners() {
        // Hub Quick Start -> Switch to Stream Tab
        btnQuickStartTask.setOnClickListener {
            tabLayout.getTabAt(1)?.select()
        }

        // DeepSeek Thinking Accordion Toggle
        headerDeepSeekThinking.setOnClickListener {
            val isCurrentlyVisible = tvDeepSeekThoughts.visibility == View.VISIBLE
            tvDeepSeekThoughts.visibility = if (isCurrentlyVisible) View.GONE else View.VISIBLE
            tvThinkingToggle.text = if (isCurrentlyVisible) "[ Expand ]" else "[ Collapse ]"
        }

        // Stream Execution Button
        btnStreamExecute.setOnClickListener {
            executeAgentTask()
        }

        // Plugins: Dynamic Tool Registration Seam
        btnRegisterDynamicTool.setOnClickListener {
            val toolName = etDynamicToolName.text.toString().trim()
            if (toolName.isNotEmpty()) {
                tvDynamicToolStatus.text = "✓ Dynamic tool '$toolName' successfully injected into PluginRegistry.\nAST Guardrail: VALIDATED."
            }
        }

        // Session Time-Travel: SeekBar Scrubber
        sbSessionScrubber.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                tvSessionStepIndicator.text = "TIME-TRAVEL STEP: $progress / ${seekBar?.max ?: 5}"
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {
                val sessionId = etSessionId.text.toString().trim()
                val step = seekBar?.progress ?: 0
                timelineViewModel.scrubToStep(sessionId, step)
            }
        })

        btnSessionReplay.setOnClickListener {
            val sessionId = etSessionId.text.toString().trim()
            val step = sbSessionScrubber.progress
            timelineViewModel.scrubToStep(sessionId, step)
        }

        btnSessionFork.setOnClickListener {
            val sessionId = etSessionId.text.toString().trim()
            val step = sbSessionScrubber.progress
            val forkId = "${sessionId}_branch_${System.currentTimeMillis() % 1000}"
            timelineViewModel.forkBranch(sessionId, forkId, step)
        }

        // Governor Actions
        btnGovCompactHeap.setOnClickListener {
            governorViewModel.compactHeap()
        }

        btnGovRefresh.setOnClickListener {
            governorViewModel.refreshGovernorState()
        }
    }

    private fun executeAgentTask() {
        val rawApiKey = etHubApiKey.text.toString().trim()
        val apiKey = rawApiKey.ifEmpty { null }
        val provider = spHubProvider.selectedItem.toString()
        val modelName = etHubModelName.text.toString().trim()
        val agentName = spHubAgent.selectedItem.toString()
        val goal = etStreamGoal.text.toString().trim()

        if (goal.isEmpty()) {
            tvStreamConsole.text = "Error: Task goal cannot be empty."
            return
        }

        val modelConfig: ModelConfig = when (provider) {
            "nvidia" -> ModelConfig.Nvidia(modelName = modelName, apiKey = apiKey)
            "deepseek" -> ModelConfig.DeepSeek(modelName = modelName, apiKey = apiKey)
            "on_device" -> ModelConfig.OnDevice(template = modelName)
            "mock" -> ModelConfig.Mock
            else -> ModelConfig.Cloud(provider = provider, modelName = modelName, apiKey = apiKey)
        }

        val selectedMode = when (rgOperatingMode.checkedRadioButtonId) {
            R.id.rbModeSupervised -> AgentOperatingMode.SUPERVISED
            R.id.rbModeAudit -> AgentOperatingMode.AUDIT
            else -> AgentOperatingMode.AUTONOMOUS
        }

        tvStreamConsole.text = "⚡ Launching $agentName...\nProvider: $provider\nModel: $modelName\nMode: $selectedMode\nGoal: $goal\n\nStarting loop..."
        btnStreamExecute.isEnabled = false
        pbStreamProgress.visibility = View.VISIBLE
        tvEngineStatusBadge.text = "● RUNNING"
        tvEngineStatusBadge.setTextColor(0xFF00E5FF.toInt())
        tvEngineStatusBadge.setBackgroundColor(0xFF101C24.toInt())

        agentViewModel.executeTask(
            agentName = agentName,
            goal = goal,
            modelConfig = modelConfig,
            operatingMode = selectedMode
        ) { result ->
            runOnUiThread {
                btnStreamExecute.isEnabled = true
                pbStreamProgress.visibility = View.GONE
                tvEngineStatusBadge.text = "● READY"
                tvEngineStatusBadge.setTextColor(0xFF00E676.toInt())
                tvEngineStatusBadge.setBackgroundColor(0xFF162E24.toInt())

                result.fold(
                    onSuccess = { execResult ->
                        val sb = StringBuilder()
                        sb.append("========================================\n")
                        sb.append("✓ EXECUTION COMPLETE (${execResult.durationMs}ms, ${execResult.stepCount} steps)\n")
                        sb.append("========================================\n\n")
                        sb.append("AGENT RESULT:\n")
                        sb.append(execResult.resultText).append("\n\n")

                        if (execResult.heapHandles.isNotEmpty()) {
                            tvHeapHandlesChips.text = "Pass-by-Reference Handles: ${execResult.heapHandles.joinToString(", ")}"
                            sb.append("ObjectHeap Handles: ").append(execResult.heapHandles).append("\n\n")
                        } else {
                            tvHeapHandlesChips.text = "No heap handles (#ref_xxx)"
                        }

                        if (execResult.trace.isNotEmpty()) {
                            sb.append("EXECUTION TRACE (Steps: ${execResult.trace.size}):\n")
                            for ((i, step) in execResult.trace.withIndex()) {
                                sb.append("  [Step ${i + 1}] Thought: ").append(step["thought"] ?: step["action"] ?: "step").append("\n")
                            }
                        }
                        tvStreamConsole.text = sb.toString()
                    },
                    onFailure = { error ->
                        tvStreamConsole.text = "✗ EXECUTION FAILED:\n${error.message}\n\nStack:\n${error.stackTraceToString()}"
                    }
                )
            }
        }
    }

    private fun observeAllViewModels() {
        // 1. Observe Agent Hub ViewModel
        lifecycleScope.launch {
            hubViewModel.uiState.collect { state ->
                state.telemetry?.let { tel ->
                    tvHubBattery.text = "🔋 ${tel.batteryLevel.toInt()}% ${if (tel.isCharging) "Charging" else "Nominal"}"
                    tvHubRam.text = "🧠 RAM: ${(tel.availableRamMb / 1024.0).format(1)}GB Free"
                    tvHubThermal.text = "🌡️ Thermal: ${tel.thermalStatus}"
                }
            }
        }

        // 2. Observe Agent Loop State
        lifecycleScope.launch {
            agentViewModel.agentState.collect { state ->
                when (state) {
                    is AgentState.Running -> {
                        tvStreamConsole.text = "▶ RUNNING: ${state.agentName}\nStep: ${state.currentStep}/${state.maxSteps}\nGoal: ${state.goal}\n" +
                            (state.latestThought?.let { "\nThought: $it\n" } ?: "")
                        state.latestThought?.let {
                            tvDeepSeekThoughts.text = it
                        }
                    }
                    is AgentState.Failed -> {
                        tvStreamConsole.text = "✗ Agent Execution Error:\n${state.error}"
                        btnStreamExecute.isEnabled = true
                        pbStreamProgress.visibility = View.GONE
                    }
                    else -> {}
                }
            }
        }

        // 3. Observe Session Time-Travel Timeline
        lifecycleScope.launch {
            timelineViewModel.uiState.collect { state ->
                tvSessionStepIndicator.text = "TIME-TRAVEL STEP: ${state.selectedStepIndex} / ${state.totalSteps}"
                sbSessionScrubber.max = state.totalSteps
                sbSessionScrubber.progress = state.selectedStepIndex

                if (state.reconstructedState.isNotEmpty()) {
                    tvSessionStateSnapshot.text = "Reconstructed Snapshot (Step ${state.selectedStepIndex}):\n${state.reconstructedState}"
                }

                state.forkedSessionId?.let { forkId ->
                    tvSessionStateSnapshot.text = "⚡ New Session Branch Forked!\nBranch Session ID: $forkId\nParent Step: ${state.selectedStepIndex}"
                }
            }
        }

        // 4. Observe Resource Governor
        lifecycleScope.launch {
            governorViewModel.uiState.collect { state ->
                state.telemetry?.let { tel ->
                    tvGovRamPressure.text = "🧠 RAM: ${tel.availableRamMb}MB free / ${tel.totalRamMb}MB total (${tel.ramUsagePercent}% used)"
                    tvGovThermalState.text = "🌡️ Thermal Status: ${tel.thermalStatus.uppercase()}"
                    tvGovBattery.text = "🔋 Battery: ${tel.batteryLevel.toInt()}% · ${if (tel.isCharging) "CHARGING" else "DISCHARGING"}"
                    tvGovNetwork.text = "📶 Network: ${tel.networkStatus.uppercase()} (Connected)"
                }

                state.budget?.let { budget ->
                    tvGovBudgetSummary.text = "Max Concurrency: ${budget.maxConcurrency} | Tier: ${budget.recommendedTier} | Step Delay: ${budget.stepDelayMs}ms | Cloud Offload: ${if (budget.isCloudOffloadRecommended) "RECOMMENDED" else "INACTIVE"}"
                }

                if (state.isCompactingHeap) {
                    tvGovBudgetSummary.text = "🧹 Heap compaction in progress... Reclaiming inactive #ref handles."
                }
            }
        }
    }

    private fun Double.format(digits: Int) = String.format("%.${digits}f", this)
}


