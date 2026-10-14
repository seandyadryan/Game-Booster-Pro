package com.deploydulupulangnanti.gameboosterpro

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LatencySummaryTest {
    @Test
    fun failuresAreExcludedFromAverageAndJitter() {
        val result = summarizeLatency(listOf(12.0, null, 16.0, 20.0, 16.0))
        assertEquals(16.0, result["averageMs"])
        assertEquals(12.0, result["minMs"])
        assertEquals(20.0, result["maxMs"])
        assertEquals(4.0, result["jitterMs"])
        assertEquals(1, result["failedProbes"])
        assertEquals(5, result["totalProbes"])
    }

    @Test
    fun allFailuresHaveNoNumericLatency() {
        val result = summarizeLatency(List(5) { null })
        for (key in listOf("averageMs", "minMs", "maxMs", "jitterMs")) assertNull(result[key])
        assertEquals(5, result["failedProbes"])
    }

    @Test
    fun oneSuccessHasAnAverageButNoJitter() {
        val result = summarizeLatency(listOf(null, 18.0, null, null, null))
        assertEquals(18.0, result["averageMs"])
        assertEquals(18.0, result["minMs"])
        assertEquals(18.0, result["maxMs"])
        assertNull(result["jitterMs"])
    }
}
