package com.mobi.nooa

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/**
 * Supported on-device local model formats.
 */
enum class ModelFormat {
    GGUF,
    LITERTLM,
    CUSTOM
}

/**
 * Specification and metadata for an on-device downloadable model.
 */
data class ModelSpec(
    val id: String,
    val name: String,
    val format: ModelFormat,
    val quantization: String,
    val sizeBytes: Long,
    val sha256: String? = null,
    val contextLength: Int = 4096,
    val minRamMb: Int = 2048,
    val downloadUrl: String? = null,
    val localFileName: String = "."
)

/**
 * Model storage and download manager for on-device GGUF / LiteRT weights.
 * Manages local caching in context.filesDir/models/ and performs integrity checks.
 */
class ModelStorageManager(private val context: Context) {

    val modelsDir: File = File(context.filesDir, "models").apply {
        if (!exists()) {
            mkdirs()
        }
    }

    companion object {
        val RECOMMENDED_CATALOG = listOf(
            ModelSpec(
                id = "llama-3.2-1b-instruct-q4",
                name = "Llama 3.2 1B Instruct",
                format = ModelFormat.GGUF,
                quantization = "Q4_K_M",
                sizeBytes = 800_000_000L,
                contextLength = 4096,
                minRamMb = 2048,
                localFileName = "llama-3.2-1b-instruct-q4_k_m.gguf"
            ),
            ModelSpec(
                id = "llama-3.2-3b-instruct-q4",
                name = "Llama 3.2 3B Instruct",
                format = ModelFormat.GGUF,
                quantization = "Q4_K_M",
                sizeBytes = 2_100_000_000L,
                contextLength = 4096,
                minRamMb = 4096,
                localFileName = "llama-3.2-3b-instruct-q4_k_m.gguf"
            ),
            ModelSpec(
                id = "qwen-2.5-1.5b-instruct-q4",
                name = "Qwen 2.5 1.5B Instruct",
                format = ModelFormat.GGUF,
                quantization = "Q4_K_M",
                sizeBytes = 1_100_000_000L,
                contextLength = 4096,
                minRamMb = 3072,
                localFileName = "qwen-2.5-1.5b-instruct-q4_k_m.gguf"
            ),
            ModelSpec(
                id = "gemma-2-2b-it-litert",
                name = "Gemma 2 2B IT",
                format = ModelFormat.LITERTLM,
                quantization = "INT4",
                sizeBytes = 1_400_000_000L,
                contextLength = 2048,
                minRamMb = 3072,
                localFileName = "gemma-2-2b-it.litert"
            )
        )
    }

    /** Lists all model files present in the local models storage directory. */
    fun listLocalFiles(): List<File> {
        return modelsDir.listFiles()?.filter { it.isFile }?.toList() ?: emptyList()
    }

    /** Resolves the destination [File] for a given [ModelSpec]. */
    fun getModelFile(spec: ModelSpec): File {
        return File(modelsDir, spec.localFileName)
    }

    /** Checks if the model file is already present and matches the expected size. */
    fun isModelDownloaded(spec: ModelSpec): Boolean {
        val file = getModelFile(spec)
        return file.exists() && file.length() > 0
    }

    /**
     * Computes the SHA-256 checksum of a local file.
     */
    suspend fun computeSha256(file: File): String = withContext(Dispatchers.IO) {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { fis ->
            val buffer = ByteArray(65536)
            var bytesRead: Int
            while (fis.read(buffer).also { bytesRead = it } != -1) {
                digest.update(buffer, 0, bytesRead)
            }
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }

    /**
     * Inspects a GGUF file header and extracts magic numbers and basic metadata.
     */
    suspend fun inspectGgufHeader(file: File): Map<String, Any> = withContext(Dispatchers.IO) {
        if (!file.exists() || file.length() < 16) {
            return@withContext mapOf("error" to "File does not exist or is too small")
        }

        FileInputStream(file).use { fis ->
            val headerBytes = ByteArray(16)
            val read = fis.read(headerBytes)
            if (read < 16) {
                return@withContext mapOf("error" to "Unable to read header bytes")
            }

            val buffer = ByteBuffer.wrap(headerBytes).order(ByteOrder.LITTLE_ENDIAN)
            val magic0 = buffer.get()
            val magic1 = buffer.get()
            val magic2 = buffer.get()
            val magic3 = buffer.get()
            val magic = String(byteArrayOf(magic0, magic1, magic2, magic3))

            val version = buffer.int
            val tensorCount = buffer.long

            mapOf(
                "magic" to magic,
                "isGguf" to (magic == "GGUF"),
                "version" to version,
                "tensorCount" to tensorCount,
                "fileSizeBytes" to file.length()
            )
        }
    }

    /**
     * Downloads a model file with progress tracking and optional checksum verification.
     */
    suspend fun downloadModel(
        spec: ModelSpec,
        onProgress: (Float) -> Unit = {}
    ): Result<File> = withContext(Dispatchers.IO) {
        val downloadUrl = spec.downloadUrl
            ?: return@withContext Result.failure(IllegalArgumentException("No download URL specified for "))

        val targetFile = getModelFile(spec)
        val tempFile = File(modelsDir, ".tmp")

        try {
            val url = URL(downloadUrl)
            val connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 30000
                requestMethod = "GET"
            }

            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                return@withContext Result.failure(
                    IllegalStateException("HTTP download failed with code ")
                )
            }

            val totalBytes = connection.contentLengthLong
            var downloadedBytes = 0L

            connection.inputStream.use { input: InputStream ->
                FileOutputStream(tempFile).use { output ->
                    val buffer = ByteArray(32768)
                    var bytesRead: Int
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        downloadedBytes += bytesRead
                        if (totalBytes > 0) {
                            onProgress(downloadedBytes.toFloat() / totalBytes)
                        }
                    }
                }
            }

            if (spec.sha256 != null) {
                val computedHash = computeSha256(tempFile)
                if (!computedHash.equals(spec.sha256, ignoreCase = true)) {
                    tempFile.delete()
                    return@withContext Result.failure(
                        SecurityException("SHA-256 checksum mismatch for ")
                    )
                }
            }

            if (targetFile.exists()) {
                targetFile.delete()
            }
            tempFile.renameTo(targetFile)
            Result.success(targetFile)
        } catch (e: Exception) {
            if (tempFile.exists()) {
                tempFile.delete()
            }
            Result.failure(e)
        }
    }
}
