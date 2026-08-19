package com.mobi.nooa

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

/**
 * Android WorkManager worker for scheduled and periodic autonomous agent tasks
 * (e.g. daily memory summarization, scheduled sensor checks, background sync).
 */
class MobiNooaWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val taskGoal = inputData.getString("task_goal") ?: return Result.failure()
        val agentClass = inputData.getString("agent_class") ?: "GeneralMobileAgent"
        val maxSteps = inputData.getInt("max_steps", 10)

        return try {
            // Delegates to the headless Flutter/Dart bridge (see
            // MobiNooaBridge and docs/decisions/0007-close-dart-android-bridge-gap.md)
            // so scheduled/periodic work runs the real mobi_nooa_core agent
            // loop instead of a stub.
            val bridge = MobiNooaBridge.getInstance(applicationContext)
            val response = bridge.runAgentLoop(
                agentName = agentClass,
                goal = taskGoal,
                maxSteps = maxSteps,
            )

            val error = response["error"] as? String
            if (error != null) {
                Result.retry()
            } else {
                Result.success()
            }
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
