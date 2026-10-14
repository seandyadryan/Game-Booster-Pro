package com.deploydulupulangnanti.gameboosterpro

import kotlin.math.abs

internal fun summarizeLatency(samples: List<Double?>): Map<String, Any?> {
    val successful = samples.filterNotNull()
    // Failed probes do not become zero latency and break the sequence used for jitter.
    val differences = samples.zipWithNext().mapNotNull { (a, b) ->
        if (a != null && b != null) abs(a - b) else null
    }
    return mapOf(
        "samplesMs" to samples,
        "averageMs" to successful.takeIf { it.isNotEmpty() }?.average(),
        "minMs" to successful.minOrNull(),
        "maxMs" to successful.maxOrNull(),
        "jitterMs" to differences.takeIf { it.isNotEmpty() }?.average(),
        "failedProbes" to samples.count { it == null },
        "totalProbes" to samples.size
    )
}
