package com.seandyadryan.game_booster_pro

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "game_booster_pro/system"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler {
            call,
            result ->
            when (call.method) {
                "getSystemStatus" -> result.success(getSystemStatus())
                "cleanCache" -> result.success(cleanCache())
                "closeBackgroundApps" -> result.success(closeBackgroundApps())
                "enableDnd" -> result.success(enableDnd())
                else -> result.notImplemented()
            }
        }
    }

    private fun getSystemStatus(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        val procMemory = readProcMemoryInfo()
        val totalRamBytes = procMemory.first ?: memoryInfo.totalMem
        val availableRamBytes = procMemory.second ?: memoryInfo.availMem

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val dndPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            notificationManager.isNotificationPolicyAccessGranted
        val dndEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.currentInterruptionFilter !=
                NotificationManager.INTERRUPTION_FILTER_ALL
        } else {
            false
        }

        return mapOf(
            "totalRamBytes" to totalRamBytes,
            "availableRamBytes" to availableRamBytes,
            "totalRamMb" to (totalRamBytes / 1024 / 1024).toInt(),
            "availableRamMb" to (availableRamBytes / 1024 / 1024).toInt(),
            "lowMemory" to memoryInfo.lowMemory,
            "refreshRate" to getRefreshRate(),
            "dndPermission" to dndPermission,
            "dndEnabled" to dndEnabled
        )
    }

    private fun cleanCache(): Long {
        val before = cacheSize(cacheDir) + externalCacheDirs.filterNotNull().sumOf { cacheSize(it) }
        deleteChildren(cacheDir)
        externalCacheDirs.filterNotNull().forEach { deleteChildren(it) }
        val after = cacheSize(cacheDir) + externalCacheDirs.filterNotNull().sumOf { cacheSize(it) }
        return (before - after).coerceAtLeast(0)
    }

    private fun closeBackgroundApps(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        activityManager.killBackgroundProcesses(packageName)
        onTrimMemory(ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL)
        System.gc()

        return mapOf(
            "success" to true,
            "message" to "Background aplikasi diringankan."
        )
    }

    private fun enableDnd(): Map<String, Any> {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return mapOf(
                "enabled" to false,
                "permission" to false,
                "message" to "Dont Disturb membutuhkan Android 6 atau lebih baru."
            )
        }

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
            return mapOf(
                "enabled" to false,
                "permission" to false,
                "message" to "Aktifkan izin Dont Disturb untuk Game Booster Pro."
            )
        }

        notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        return mapOf(
            "enabled" to true,
            "permission" to true,
            "message" to "Mode Dont Disturb aktif."
        )
    }

    private fun readProcMemoryInfo(): Pair<Long?, Long?> {
        var total: Long? = null
        var available: Long? = null

        runCatching {
            File("/proc/meminfo").forEachLine { line ->
                when {
                    line.startsWith("MemTotal:") -> total = parseMemoryLine(line)
                    line.startsWith("MemAvailable:") -> available = parseMemoryLine(line)
                }
            }
        }

        return Pair(total, available)
    }

    private fun parseMemoryLine(line: String): Long? {
        val value = line.split(Regex("\\s+"))
            .firstOrNull { token -> token.all { char -> char.isDigit() } }
            ?.toLongOrNull()
        return value?.times(1024)
    }

    private fun getRefreshRate(): Float {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.refreshRate ?: 0f
        } else {
            @Suppress("DEPRECATION")
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.refreshRate
        }
    }

    private fun cacheSize(file: File?): Long {
        if (file == null || !file.exists()) {
            return 0
        }
        if (file.isFile) {
            return file.length()
        }
        return file.listFiles()?.sumOf { cacheSize(it) } ?: 0
    }

    private fun deleteChildren(file: File?) {
        if (file == null || !file.exists() || !file.isDirectory) {
            return
        }
        file.listFiles()?.forEach { child ->
            if (child.isDirectory) {
                deleteChildren(child)
            }
            child.delete()
        }
    }
}
