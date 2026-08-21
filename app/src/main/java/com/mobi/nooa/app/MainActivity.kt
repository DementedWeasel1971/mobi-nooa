package com.mobi.nooa.app

import android.os.Bundle
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.mobi.nooa.di.MobiNooaContainer
import com.mobi.nooa.domain.AgentOperatingMode
import com.mobi.nooa.domain.AgentState
import com.mobi.nooa.domain.ModelConfig
import com.mobi.nooa.presentation.AgentViewModel
import com.mobi.nooa.presentation.MobiNooaViewModelFactory
import kotlinx.coroutines.launch

/**
 * Android Host Activity providing an interactive UI for typing API keys,
 * configuring model providers (NVIDIA NIM, DeepSeek, On-Device, Cloud),
 * and executing autonomous agent tasks.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var container: MobiNooaContainer
    private lateinit var agentViewModel: AgentViewModel

    private lateinit var apiKeyInput: EditText
    private lateinit var providerSpinner: Spinner
    private lateinit var modelInput: EditText
    private lateinit var agentSpinner: Spinner
    private lateinit var taskInput: EditText
    private lateinit var btnRunAgent: Button
    private lateinit var outputView: TextView

    private val providers = listOf("nvidia", "deepseek", "openai", "gemini", "on_device", "mock")
    private val agents = listOf(
        "AutonomousDeviceAgent",
        "DataAnalystAgent",
        "AutonomousCodingAgent",
        "BenchAgent",
        "GeneralMobileAgent"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize Clean Architecture Container & ViewModel
        container = MobiNooaContainer(applicationContext)
        val factory = MobiNooaViewModelFactory(container)
        agentViewModel = ViewModelProvider(this, factory)[AgentViewModel::class.java]

        // Bind Views
        apiKeyInput = findViewById(R.id.apiKeyInput)
        providerSpinner = findViewById(R.id.providerSpinner)
        modelInput = findViewById(R.id.modelInput)
        agentSpinner = findViewById(R.id.agentSpinner)
        taskInput = findViewById(R.id.taskInput)
        btnRunAgent = findViewById(R.id.btnRunAgent)
        outputView = findViewById(R.id.outputView)

        setupSpinners()
        setupListeners()
        observeState()
    }

    private fun setupSpinners() {
        val providerAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, providers)
        providerSpinner.adapter = providerAdapter

        val agentAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, agents)
        agentSpinner.adapter = agentAdapter

        providerSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                when (providers[position]) {
                    "nvidia" -> modelInput.setText("meta/llama-3.3-70b-instruct")
                    "deepseek" -> modelInput.setText("deepseek-reasoner")
                    "openai" -> modelInput.setText("gpt-4o")
                    "gemini" -> modelInput.setText("gemini-1.5-flash")
                    "on_device" -> modelInput.setText("llama3")
                    "mock" -> modelInput.setText("mock-agent-v1")
                }
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
    }

    private fun setupListeners() {
        btnRunAgent.setOnClickListener {
            val rawApiKey = apiKeyInput.text.toString().trim()
            val apiKey = rawApiKey.ifEmpty { null }
            val provider = providerSpinner.selectedItem.toString()
            val modelName = modelInput.text.toString().trim()
            val agentName = agentSpinner.selectedItem.toString()
            val goal = taskInput.text.toString().trim()

            if (goal.isEmpty()) {
                outputView.text = "Error: Goal instruction cannot be empty."
                return@setOnClickListener
            }

            val modelConfig: ModelConfig = when (provider) {
                "nvidia" -> ModelConfig.Nvidia(modelName = modelName, apiKey = apiKey)
                "deepseek" -> ModelConfig.DeepSeek(modelName = modelName, apiKey = apiKey)
                "on_device" -> ModelConfig.OnDevice(template = modelName)
                "mock" -> ModelConfig.Mock
                else -> ModelConfig.Cloud(provider = provider, modelName = modelName, apiKey = apiKey)
            }

            outputView.text = "⚡ Launching $agentName...\nProvider: $provider\nModel: $modelName\nGoal: $goal\n\nStarting loop..."
            btnRunAgent.isEnabled = false

            agentViewModel.executeTask(
                agentName = agentName,
                goal = goal,
                modelConfig = modelConfig,
                operatingMode = AgentOperatingMode.AUTONOMOUS
            ) { result ->
                runOnUiThread {
                    btnRunAgent.isEnabled = true
                    result.fold(
                        onSuccess = { execResult ->
                            val sb = StringBuilder()
                            sb.append("========================================\n")
                            sb.append("✓ EXECUTION COMPLETE (${execResult.durationMs}ms, ${execResult.stepCount} steps)\n")
                            sb.append("========================================\n\n")
                            sb.append("AGENT RESULT:\n")
                            sb.append(execResult.resultText).append("\n\n")
                            if (execResult.heapHandles.isNotEmpty()) {
                                sb.append("ObjectHeap Handles: ").append(execResult.heapHandles).append("\n\n")
                            }
                            if (execResult.trace.isNotEmpty()) {
                                sb.append("EXECUTION TRACE (Steps: ${execResult.trace.size}):\n")
                                for ((i, step) in execResult.trace.withIndex()) {
                                    sb.append("  [Step ${i + 1}] Thought: ").append(step["thought"] ?: step["action"] ?: "step").append("\n")
                                }
                            }
                            outputView.text = sb.toString()
                        },
                        onFailure = { error ->
                            outputView.text = "✗ EXECUTION FAILED:\n${error.message}\n\nStack:\n${error.stackTraceToString()}"
                        }
                    )
                }
            }
        }
    }

    private fun observeState() {
        lifecycleScope.launch {
            agentViewModel.agentState.collect { state ->
                when (state) {
                    is AgentState.Running -> {
                        outputView.text = "▶ RUNNING: ${state.agentName}\nStep: ${state.currentStep}/${state.maxSteps}\nGoal: ${state.goal}\n" +
                            (state.latestThought?.let { "\nThought: $it\n" } ?: "")
                    }
                    is AgentState.Success -> {
                        // Handled in completion callback
                    }
                    is AgentState.Failed -> {
                        outputView.text = "✗ Agent Execution Error:\n${state.error}"
                        btnRunAgent.isEnabled = true
                    }
                    is AgentState.Idle -> {
                        // Ready
                    }
                    else -> {}
                }
            }
        }
    }

}
