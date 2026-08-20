package com.mobi.nooa

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Android Foreground Service allowing autonomous mobi-nooa agents to execute continuous loops
 * without being terminated by Android battery optimization / process killing.
 */
class MobiNooaService : Service() {

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Default + serviceJob)

    companion object {
        const val CHANNEL_ID = "mobi_nooa_agent_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START_AGENT = "com.mobi.nooa.ACTION_START_AGENT"
        const val ACTION_STOP_AGENT = "com.mobi.nooa.ACTION_STOP_AGENT"
        const val EXTRA_TASK_GOAL = "extra_task_goal"
        const val EXTRA_AGENT_NAME = "extra_agent_name"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_START_AGENT) {
            val agentName = intent.getStringExtra(EXTRA_AGENT_NAME) ?: "MobiAgent"
            val goal = intent.getStringExtra(EXTRA_TASK_GOAL) ?: "Autonomous execution"

            startForeground(NOTIFICATION_ID, createForegroundNotification(agentName, goal))

            serviceScope.launch {
                runAgentLoop(agentName, goal)
            }
        } else if (action == ACTION_STOP_AGENT) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun createForegroundNotification(agentName: String, goal: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("mobi-nooa: $agentName Active")
            .setContentText("Running task: $goal")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "mobi-nooa Agent Execution",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live status of active mobile OO-Agents"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private suspend fun runAgentLoop(agentName: String, goal: String) {
        // Delegates to the headless Flutter/Dart bridge (see MobiNooaBridge
        // and docs/decisions/0007-close-dart-android-bridge-gap.md). The
        // Dart side executes the real NooaAgent loop via
        // AgentBridgeDispatcher.runAgentLoop and returns a JSON result.
        val bridge = MobiNooaBridge.getInstance(applicationContext)
        val response = bridge.runAgentLoop(agentName = agentName, goal = goal)

        val error = response["error"] as? String
        if (error != null) {
            showResultNotification(agentName, success = false, message = error)
        } else {
            val result = response["result"]?.toString() ?: "(no result)"
            showResultNotification(agentName, success = true, message = result)
        }
    }

    private fun showResultNotification(agentName: String, success: Boolean, message: String) {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (success) "$agentName finished" else "$agentName failed")
            .setContentText(message.take(200))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID + 1, builder.build())
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }
}
