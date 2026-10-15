package com.deploydulupulangnanti.gameboosterpro

import android.app.ActivityManager
import android.app.NotificationManager
import android.app.AppOpsManager
import android.app.usage.StorageStatsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import android.os.Process
import android.os.UserHandle
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.os.storage.StorageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.TextView
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
    private val monitorHandler = Handler(Looper.getMainLooper())
    private val monitorExecutor = Executors.newSingleThreadExecutor()
    private val cacheExecutor = Executors.newSingleThreadExecutor()
    private val networkExecutor = Executors.newSingleThreadExecutor()
    private var lastForegroundPackage: String? = null
    private var lastForegroundTimestamp = 0L
    private var monitorHasSeenGame = false
    private var monitorView: TextView? = null
    private var monitorPackage: String? = null
    private var pendingGamePackage: String? = null
    private var usageSettingsOpenedForGame = false
    private val monitorTick = object : Runnable {
        override fun run() {
            val target = monitorPackage ?: return
            monitorExecutor.execute {
                val foreground = runCatching { currentForegroundPackage() }.getOrNull()
                monitorHandler.post {
                    if (monitorPackage != target) return@post
                    if (foreground == target) monitorHasSeenGame = true
                    monitorView?.visibility = if (foreground == target) View.VISIBLE else View.GONE
                    monitorView?.text = "Display Refresh Rate: ${getRefreshRate().toInt()} Hz  |  ×"
                    if (monitorHasSeenGame && foreground == packageName) stopGameMonitor()
                    else monitorHandler.postDelayed(this, 1000)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler {
            call,
            result ->
            try { when (call.method) {
                "getSystemStatus" -> result.success(getSystemStatus())
                "getOwnCacheStats" -> cacheExecutor.execute {
                    val stats = runCatching { mapOf("cacheBytes" to ownCacheCleaner().size()) }
                    runOnUiThread {
                        stats.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("CACHE_ERROR", "Unable to read app cache.", null) }
                        )
                    }
                }
                "checkNetworkLatency" -> networkExecutor.execute {
                    val checked = runCatching { NetworkDiagnostics(this).check() }
                    runOnUiThread {
                        checked.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("NETWORK_ERROR", it.message ?: "Network check failed.", null) }
                        )
                    }
                }
                "cleanCache" -> cacheExecutor.execute {
                    val cleaned = runCatching { cleanCache() }
                    runOnUiThread {
                        cleaned.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("CACHE_ERROR", it.message, null) }
                        )
                    }
                }
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
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "hasOverlayAccess" -> result.success(Settings.canDrawOverlays(this))
                "requestUsageAccess" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "getTopCachedApps" -> cacheExecutor.execute {
                    val response = runCatching { getTopCachedApps() }
                    runOnUiThread {
                        response.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.error("CACHE_STATS_ERROR", it.message, null) }
                        )
                    }
                }
                "openAppStorageSettings" -> {
                    val target = call.argument<String>("packageName") ?: error("Select an app first.")
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$target")))
                    result.success(null)
                }
                "launchGame" -> {
                    val target = call.argument<String>("packageName") ?: error("Select a game first.")
                    require(target.isNotBlank()) { "Invalid game package ID." }
                    if (!Settings.canDrawOverlays(this) || !hasUsageAccess()) {
                        pendingGamePackage = target
                        if (!Settings.canDrawOverlays(this)) {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                            result.success(mapOf("launched" to false, "permission" to "overlay"))
                        } else {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(mapOf("launched" to false, "permission" to "usage"))
                        }
                        return@setMethodCallHandler
                    }
                    val intent = packageManager.getLaunchIntentForPackage(target) ?: error("This game is no longer installed or cannot be launched.")
                    intent.setPackage(target)
                    startGameMonitor(target)
                    startActivity(intent)
                    result.success(mapOf("launched" to true))
                }
                else -> result.notImplemented()
            } } catch (error: Exception) {
                result.error("SYSTEM_ERROR", error.message ?: "System operation failed.", null)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        val target = pendingGamePackage ?: return
        if (Settings.canDrawOverlays(this) && hasUsageAccess()) {
            pendingGamePackage = null
            window.decorView.post {
                if (!isFinishing) {
                    val intent = packageManager.getLaunchIntentForPackage(target)
                    if (intent != null) {
                        startGameMonitor(target)
                        startActivity(intent.setPackage(target))
                    }
                }
            }
        } else if (Settings.canDrawOverlays(this)) {
            if (!usageSettingsOpenedForGame) {
                usageSettingsOpenedForGame = true
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
            } else {
                pendingGamePackage = null
                usageSettingsOpenedForGame = false
            }
        }
    }

    override fun onDestroy() {
        stopGameMonitor()
        monitorExecutor.shutdownNow()
        cacheExecutor.shutdownNow()
        networkExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun getTopCachedApps(): List<Map<String, Any>> {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) { "App cache ranking requires Android 8 or later." }
        check(hasUsageAccess()) { "Grant Usage Access to view app cache sizes." }
        val statsManager = getSystemService(Context.STORAGE_STATS_SERVICE) as StorageStatsManager
        val launchers = packageManager.queryIntentActivities(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0
        ).map { it.activityInfo.applicationInfo }.distinctBy { it.packageName }
        return launchers.mapNotNull { app ->
            runCatching {
                val stats = statsManager.queryStatsForPackage(
                    app.storageUuid ?: StorageManager.UUID_DEFAULT,
                    app.packageName,
                    UserHandle.getUserHandleForUid(app.uid)
                )
                mapOf(
                    "packageName" to app.packageName,
                    "name" to packageManager.getApplicationLabel(app).toString(),
                    "cacheBytes" to stats.cacheBytes,
                    "totalBytes" to stats.appBytes + stats.dataBytes
                )
            }.getOrNull()
        }.filter { (it["cacheBytes"] as Long) > 0 }
            .sortedByDescending { it["cacheBytes"] as Long }
            .take(5)
    }

    private fun startGameMonitor(target: String) {
        stopGameMonitor()
        lastForegroundPackage = null
        lastForegroundTimestamp = 0L
        monitorHasSeenGame = false
        if (!Settings.canDrawOverlays(this)) return
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = TextView(this).apply {
            text = "Display Refresh Rate: ${getRefreshRate().toInt()} Hz  |  ×"
            setTextColor(Color.WHITE)
            textSize = 13f
            setPadding(18, 12, 18, 12)
            setBackgroundColor(Color.argb(220, 12, 20, 16))
            elevation = 12f
            setOnClickListener { stopGameMonitor() }
        }
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL; y = 72 }
        runCatching { wm.addView(view, params) }.onSuccess {
            monitorView = view
            monitorPackage = target
            monitorHandler.post(monitorTick)
        }
    }

    private fun currentForegroundPackage(): String? {
        val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = manager.queryEvents(now - 15_000, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val resumed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            if (event.eventType == resumed && event.timeStamp >= lastForegroundTimestamp) {
                lastForegroundTimestamp = event.timeStamp
                lastForegroundPackage = event.packageName
            }
        }
        return lastForegroundPackage
    }

    private fun stopGameMonitor() {
        monitorHandler.removeCallbacks(monitorTick)
        val view = monitorView ?: return
        runCatching { (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view) }
        monitorView = null
        monitorPackage = null
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

    private fun ownCacheCleaner() = AppCacheCleaner(listOf(cacheDir, codeCacheDir) + externalCacheDirs.filterNotNull())

    private fun cleanCache(): Map<String, Long> = ownCacheCleaner().clear()

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
                "message" to "Do Not Disturb requires Android 6 or later."
            )
        }

        if (!notificationManager.isNotificationPolicyAccessGranted) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
            return mapOf(
                "enabled" to false,
                "permission" to false,
                "message" to "Allow Do Not Disturb access for Game Tools."
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
                "Strict Do Not Disturb requested. Calls can still arrive, but sounds including alarms and media are silenced."
            } else if (actual) {
                "The app's Do Not Disturb request ended. System Do Not Disturb is still active; check other rules."
            } else {
                "Previous Do Not Disturb settings restored."
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

}
