package com.deploydulupulangnanti.gameboosterpro

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

class AppCacheCleanerTest {
    @Test
    fun removesOnlyCacheFilesAndReportsTheirBytes() {
        val fixture = Files.createTempDirectory("game-booster-cache-test").toFile()
        try {
            val internal = File(fixture, "cache").apply { mkdirs() }
            val external = File(fixture, "external-cache").apply { mkdirs() }
            val preferences = File(fixture, "preferences.xml").apply { writeText("keep-me") }
            File(internal, "image.tmp").writeBytes(ByteArray(512))
            val nested = File(internal, "nested").apply { mkdirs() }
            File(nested, "data.tmp").writeBytes(ByteArray(1024))
            File(external, "download.tmp").writeBytes(ByteArray(256))
            val cleaner = AppCacheCleaner(listOf(internal, external))
            assertEquals(1792L, cleaner.size())
            val report = cleaner.clear()
            assertEquals(1792L, report["beforeBytes"])
            assertEquals(1792L, report["freedBytes"])
            assertEquals(0L, report["afterBytes"])
            assertEquals(0L, report["failedFiles"])
            assertEquals("keep-me", preferences.readText())
            assertTrue(internal.isDirectory)
            assertTrue(external.isDirectory)
            assertEquals(0L, cleaner.clear()["freedBytes"])
        } finally {
            fixture.deleteRecursively()
        }
    }

    @Test
    fun emptyOrMissingCacheIsAnHonestZero() {
        val fixture = Files.createTempDirectory("game-booster-empty-test").toFile()
        try {
            val cleaner = AppCacheCleaner(listOf(File(fixture, "not-created")))
            assertEquals(0L, cleaner.size())
            assertEquals(mapOf("beforeBytes" to 0L, "afterBytes" to 0L, "freedBytes" to 0L, "failedFiles" to 0L), cleaner.clear())
        } finally {
            fixture.deleteRecursively()
        }
    }
}
