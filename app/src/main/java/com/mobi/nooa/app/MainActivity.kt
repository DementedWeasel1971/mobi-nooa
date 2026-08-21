package com.mobi.nooa.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.ViewModelProvider
import com.mobi.nooa.di.MobiNooaContainer
import com.mobi.nooa.presentation.AgentViewModel
import com.mobi.nooa.presentation.MobiNooaViewModelFactory

/**
 * Android Host Activity demonstrating Clean Architecture initialization with
 * [MobiNooaContainer] and [AgentViewModel].
 */
class MainActivity : AppCompatActivity() {

    private lateinit var container: MobiNooaContainer
    private lateinit var agentViewModel: AgentViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize lightweight Dependency Container
        container = MobiNooaContainer(applicationContext)

        // Instantiate ViewModel using the Custom Factory
        val factory = MobiNooaViewModelFactory(container)
        agentViewModel = ViewModelProvider(this, factory)[AgentViewModel::class.java]
    }
}
