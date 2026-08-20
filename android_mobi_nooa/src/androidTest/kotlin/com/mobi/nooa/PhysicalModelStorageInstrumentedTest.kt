package com.mobi.nooa

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * On-Device Physical Model Storage Instrumented Test Suite.
 * Validates GGUF local model storage, directory isolation, header parsing, and SHA-256
 * verification directly on the physical device's flash storage.
 */
@RunWith(AndroidJUnit4::class)
class PhysicalModelStorageInstrumentedTest {

    private lateinit var context: Context
    private lateinit var storageManager: ModelStorageManager

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        storageManager = ModelStorageManager(context)
    }

    @Test
    fun testPhysicalStorageDirectoryCreationAndCatalog() {
        val models = storageManager.listLocalFiles()
        assertNotNull("Model files list must not be null on physical storage", models)

        val modelsDir = File(context.filesDir, "models")
        assertTrue("Models directory must exist on device storage", modelsDir.exists())
        assertTrue("Models directory must be a directory", modelsDir.isDirectory)
        assertTrue("Catalog must have recommended models", ModelStorageManager.RECOMMENDED_CATALOG.isNotEmpty())
    }

    @Test
    fun testPhysicalGgufModelFileWritingAndIntegrity() = runBlocking {
        val testModelName = "test-q4-phys.gguf"
        val modelsDir = File(context.filesDir, "models")
        val testFile = File(modelsDir, testModelName)

        try {
            // Write a valid GGUF header (GGUF magic = 0x46554747, version 3, 4 tensors, 2 metadata kv)
            val headerBytes = byteArrayOf(
                0x47, 0x47, 0x55, 0x46, // 'G', 'G', 'U', 'F'
                0x03, 0x00, 0x00, 0x00, // Version 3
                0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Tensor count 4
                0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // Metadata count 2
            )
            testFile.writeBytes(headerBytes)

            val parsedHeader = storageManager.inspectGgufHeader(testFile)
            assertNotNull("GGUF header must be successfully parsed on device", parsedHeader)
            assertEquals("Magic must be GGUF", "GGUF", parsedHeader["magic"])
            assertEquals("Version must be 3", 3, parsedHeader["version"])
            assertEquals("Tensor count must be 4", 4L, parsedHeader["tensorCount"])

            // Test SHA-256 hash calculation over real device storage
            val sha256 = storageManager.computeSha256(testFile)
            assertNotNull("SHA-256 calculation must succeed on device", sha256)
            assertEquals("SHA-256 hash string must be 64 hexadecimal characters", 64, sha256.length)
        } finally {
            if (testFile.exists()) {
                testFile.delete()
            }
        }
    }
}
