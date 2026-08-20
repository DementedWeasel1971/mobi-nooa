package com.mobi.nooa

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Headless bridge into the `mobi_nooa_core` Dart agent engine, running inside
 * a background (UI-less) [FlutterEngine].
 *
 * This class is the Kotlin-side half of the bridge described in
 * `docs/decisions/0007-close-dart-android-bridge-gap.md`: it starts a
 * headless Flutter engine executing the `mobi_nooa_bridge` Dart entrypoint
 * (a thin package that forwards platform-channel calls into
 * `AgentBridgeDispatcher.handle` from `mobi_nooa_core`), and exposes a
 * simple suspend-function API (`runAgentLoop`, `listAgents`) so
 * [MobiNooaService] and [MobiNooaWorker] can call into real agent logic
 * instead of stub comments.
 *
 * Additionally, it provides the reverse channel `com.mobi.nooa/device_harness`
 * so the Dart agent core can query real Android telemetry (battery, network)
 * and trigger native actions (vibrate, system notifications) via [DeviceHarnessBridge].
 */
class MobiNooaBridge private constructor(context: Context) {

    val deviceHarness: DeviceHarnessBridge = DeviceHarnessBridge(context.applicationContext)

    private val engine: FlutterEngine = FlutterEngine(context.applicationContext).apply {
        // Executes the mobi_nooa_bridge package's headless Dart entrypoint
        // (main()), which registers the MethodChannel handler below on the
        // Dart side and forwards calls into AgentBridgeDispatcher.handle.
        dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
    }

    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)

    @Suppress("UNUSED_VARIABLE")
    private val deviceChannel = MethodChannel(engine.dartExecutor.binaryMessenger, DEVICE_CHANNEL_NAME).apply {
        setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryInfo" -> {
                    result.success(deviceHarness.getBatteryInfo())
                }
                "getNetworkStatus" -> {
                    result.success(deviceHarness.getNetworkStatus())
                }
                "showNotification" -> {
                    val channelId = call.argument<String>("channelId") ?: "mobi_nooa_channel"
                    val notificationId = call.argument<Int>("notificationId") ?: 1001
                    val title = call.argument<String>("title") ?: ""
                    val content = call.argument<String>("content") ?: ""
                    deviceHarness.showNotification(channelId, notificationId, title, content)
                    result.success(true)
                }
                "vibrate" -> {
                    val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 200L
                    deviceHarness.vibrate(durationMs)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Runs an agent to completion via `AgentBridgeDispatcher.runAgentLoop`
     * and returns its JSON response (`result`/`trace`, or `error`/`stack`).
     */
    suspend fun runAgentLoop(
        agentName: String,
        goal: String,
        inputs: Map<String, Any?> = emptyMap(),
        maxSteps: Int = 10,
        modelProvider: String = "mock",
        modelApiKey: String? = null,
    ): Map<String, Any?> {
        val request = mapOf(
            "action" to "runAgentLoop",
            "agentName" to agentName,
            "goal" to goal,
            "inputs" to inputs,
            "maxSteps" to maxSteps,
            "model" to mapOf(
                "provider" to modelProvider,
                "apiKey" to modelApiKey,
            ),
        )
        return invoke(request)
    }

    /** Lists agents registered on the Dart-side dispatcher. */
    suspend fun listAgents(): Map<String, Any?> = invoke(mapOf("action" to "listAgents"))

    private suspend fun invoke(request: Map<String, Any?>): Map<String, Any?> =
        suspendCancellableCoroutine { continuation ->
            channel.invokeMethod(
                "handle",
                request,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        @Suppress("UNCHECKED_CAST")
                        continuation.resume(result as? Map<String, Any?> ?: emptyMap())
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        continuation.resume(
                            mapOf(
                                "error" to (errorMessage ?: errorCode),
                                "details" to errorDetails?.toString(),
                            )
                        )
                    }

                    override fun notImplemented() {
                        continuation.resume(mapOf("error" to "Dart bridge entrypoint not implemented"))
                    }
                },
            )
        }

    /** Releases the underlying Flutter engine. Call when no agent work remains. */
    fun dispose() {
        engine.destroy()
    }

    companion object {
        private const val CHANNEL_NAME = "com.mobi.nooa/agent_bridge"
        private const val DEVICE_CHANNEL_NAME = "com.mobi.nooa/device_harness"

        @Volatile
        private var instance: MobiNooaBridge? = null

        /** Returns the process-wide singleton bridge, creating it on first use. */
        fun getInstance(context: Context): MobiNooaBridge {
            return instance ?: synchronized(this) {
                instance ?: MobiNooaBridge(context).also { instance = it }
            }
        }
    }
}
