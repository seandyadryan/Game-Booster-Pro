package com.deploydulupulangnanti.gameboosterpro

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.IntentFilter
import android.os.BatteryManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream
import android.graphics.Bitmap
import android.graphics.Canvas

class MainActivity : FlutterActivity() {
    private val channelName = "game_booster_pro/system"
    private val preferences by lazy { getSharedPreferences("booster", Context.MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler {
            call,
            result ->
            try { when (call.method) {
                "getSystemStatus" -> result.success(getSystemStatus())
                "cleanCache" -> Thread {
                    val cleaned = runCatching { cleanCache() }
                    runOnUiThread {
                        cleaned.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("CACHE_ERROR", it.message, null) }
                        )
                    }
                }.start()
                "closeBackgroundApps" -> result.success(closeBackgroundApps())
                "toggleDnd" -> result.success(toggleDnd(call.argument<Boolean>("enabled") ?: true))
                "openDisplaySettings" -> { startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS)); result.success(null) }
                "openDndSettings" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)); result.success(null) }
                "listGames" -> result.success(listGames())
                "getGameIcon" -> {
                    val target = call.argument<String>("packageName") ?: error("Select a game first.")
                    val drawable = packageManager.getApplicationIcon(target)
                    val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
                    try {
                        drawable.setBounds(0, 0, 96, 96)
                        drawable.draw(Canvas(bitmap))
                        val bytes = ByteArrayOutputStream().use { output ->
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                            output.toByteArray()
                        }
                        result.success(bytes)
                    } finally {
                        bitmap.recycle()
                    }
                }
                "launchGame" -> {
                    val target = call.argument<String>("packageName") ?: error("Select a game first.")
                    require(target.isNotBlank()) { "Invalid game package ID." }
                    val intent = packageManager.getLaunchIntentForPackage(target) ?: error("This game is no longer installed or cannot be launched.")
                    intent.setPackage(target)
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            } } catch (error: Exception) {
                result.error("SYSTEM_ERROR", error.message ?: "System operation failed.", null)
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
            notificationManager.currentInterruptionFilter ==
                NotificationManager.INTERRUPTION_FILTER_NONE
        } else {
            false
        }

        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        return mapOf(
            "batteryPercent" to if (level >= 0 && scale > 0) level * 100 / scale else -1,
            "batteryTemperature" to ((battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1) / 10.0),
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
        startActivity(Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS))
        return mapOf(
            "success" to false,
            "message" to "Manage apps in Android settings. To close recent apps, use your device's Recent Apps screen."
        )
    }

    private fun listGames(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(intent, 0)
            .filter { info ->
                val app = info.activityInfo.applicationInfo
                (Build.VERSION.SDK_INT >= 26 && app.category == android.content.pm.ApplicationInfo.CATEGORY_GAME) ||
                    (app.flags and android.content.pm.ApplicationInfo.FLAG_IS_GAME != 0)
            }
            .map { mapOf("name" to it.loadLabel(packageManager).toString(), "packageName" to it.activityInfo.packageName) }
            .distinctBy { it["packageName"] }.sortedBy { it["name"] }
    }

    private fun toggleDnd(enabled: Boolean): Map<String, Any> {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return mapOf(
                "enabled" to false,
                "permission" to false,
                "message" to "Dont Disturb requires Android 6 or later."
            )
        }

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
            return mapOf(
                "enabled" to false,
                "permission" to false,
                "message" to "Allow Dont Disturb access for Game Booster Pro."
            )
        }

        val current = notificationManager.currentInterruptionFilter
        if (enabled && !preferences.contains("previousDnd")) {
            preferences.edit().putInt("previousDnd", current).apply()
        }
        notificationManager.setInterruptionFilter(
            if (enabled) {
                NotificationManager.INTERRUPTION_FILTER_NONE
            } else {
                if (Build.VERSION.SDK_INT >= 35) NotificationManager.INTERRUPTION_FILTER_ALL
                else preferences.getInt("previousDnd", NotificationManager.INTERRUPTION_FILTER_ALL)
            }
        )
        if (!enabled) preferences.edit().remove("previousDnd").apply()
        val actual = notificationManager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_NONE
        return mapOf(
            "enabled" to actual,
            "permission" to true,
            "message" to if (enabled) {
                "Strict Dont Disturb requested. Calls can still arrive, but sounds including alarms and media are silenced."
            } else if (actual) {
                "The app's Dont Disturb request ended. System Dont Disturb is still active; check other rules."
            } else {
                "Previous Dont Disturb settings restored."
            }
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
