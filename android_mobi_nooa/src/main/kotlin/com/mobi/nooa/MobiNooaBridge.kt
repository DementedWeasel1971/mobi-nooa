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
 * NOTE: this file depends on the Flutter embedding
 * (`io.flutter.embedding.engine.*`), which is only available once a Flutter
 * "add-to-app" module (e.g. `mobi_nooa_bridge/`) has been generated with the
 * Flutter SDK and included in this Gradle project's `settings.gradle.kts`
 * (see the checklist in ADR 0007). Until that module exists, this file will
 * not compile — it is written ahead of that scaffolding step so the
 * integration is fully specified and only needs the generated module wired
 * in, rather than being designed from scratch on a machine with Flutter
 * installed.
 */
class MobiNooaBridge private constructor(context: Context) {

    private val engine: FlutterEngine = FlutterEngine(context.applicationContext).apply {
        // Executes the mobi_nooa_bridge package's headless Dart entrypoint
        // (main()), which registers the MethodChannel handler below on the
        // Dart side and forwards calls into AgentBridgeDispatcher.handle.
        dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
    }

    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)

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
