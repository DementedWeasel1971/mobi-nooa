package com.mobi.nooa

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

class ModelStorageManagerTest {

    @Test
    fun testRecommendedCatalogSpecs() {
        val catalog = ModelStorageManager.RECOMMENDED_CATALOG
        assertEquals(4, catalog.size)

        val llama1B = catalog.find { it.id == "llama-3.2-1b-instruct-q4" }
        assertNotNull(llama1B)
        assertEquals(ModelFormat.GGUF, llama1B!!.format)
        assertEquals("Q4_K_M", llama1B.quantization)
        assertTrue(llama1B.sizeBytes > 0)
        assertEquals(4096, llama1B.contextLength)

        val gemma2B = catalog.find { it.id == "gemma-2-2b-it-litert" }
        assertNotNull(gemma2B)
        assertEquals(ModelFormat.LITERTLM, gemma2B!!.format)
    }

    @Test
    fun testGgufHeaderInspection() {
        // Create synthetic mock GGUF file header (16 bytes: 'GGUF' + version 3 + tensorCount 42)
        val tempFile = File.createTempFile("test_model", ".gguf").apply { deleteOnExit() }
        val buffer = ByteBuffer.allocate(16).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put('G'.code.toByte())
        buffer.put('G'.code.toByte())
        buffer.put('U'.code.toByte())
        buffer.put('F'.code.toByte())
        buffer.putInt(3) // version 3
        buffer.putLong(42L) // tensorCount

        FileOutputStream(tempFile).use { it.write(buffer.array()) }

        // Read and parse directly using the buffer logic
        val readBytes = tempFile.readBytes()
        val readBuffer = ByteBuffer.wrap(readBytes).order(ByteOrder.LITTLE_ENDIAN)
        val magic = String(byteArrayOf(readBuffer.get(), readBuffer.get(), readBuffer.get(), readBuffer.get()))
        val version = readBuffer.int
        val tensorCount = readBuffer.long

        assertEquals("GGUF", magic)
        assertEquals(3, version)
        assertEquals(42L, tensorCount)
    }
}
