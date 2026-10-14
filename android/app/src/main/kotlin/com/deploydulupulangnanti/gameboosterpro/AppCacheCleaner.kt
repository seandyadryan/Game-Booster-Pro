package com.deploydulupulangnanti.gameboosterpro

import java.io.File

class AppCacheCleaner(private val roots: List<File>) {
    private fun files(): List<File> = roots.flatMap { root ->
        val boundary = root.canonicalPath + File.separator
        root.walkTopDown().onEnter { it == root || it.canonicalPath.startsWith(boundary) }
            .onFail { _, error -> throw error }
            .filter { it.isFile && it.canonicalPath.startsWith(boundary) }.toList()
    }

    fun size(): Long = files().sumOf { it.length() }

    fun clear(): Map<String, Long> {
        val candidates = files()
        val before = candidates.sumOf { it.length() }
        var freed = 0L
        var failed = 0L
        candidates.forEach { file ->
            val bytes = file.length()
            if (file.delete()) freed += bytes
            else if (file.exists()) failed++
        }
        return mapOf(
            "beforeBytes" to before,
            "afterBytes" to size(),
            "freedBytes" to freed,
            "failedFiles" to failed
        )
    }
}
