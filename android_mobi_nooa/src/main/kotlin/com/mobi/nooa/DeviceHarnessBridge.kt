package com.mobi.nooa

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Kotlin Android bridge providing access to modern Android hardware and system services
 * for the mobi-nooa harness.
 */
class DeviceHarnessBridge(private val context: Context) {

    /**
     * Reads current battery level and charging state.
     */
    fun getBatteryInfo(): Map<String, Any> {
        val ifilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val batteryStatus: Intent? = context.registerReceiver(null, ifilter)

        val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryPct = if (level >= 0 && scale > 0) level / scale.toFloat() else 0.0f

        val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL

        return mapOf(
            "batteryLevel" to batteryPct,
            "isCharging" to isCharging
        )
    }

    /**
     * Reads real-time available system RAM and low-memory state.
     */
    fun getMemoryInfo(): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val mi = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(mi)

        val availMb = (mi.availMem / (1024L * 1024L)).toInt()
        val totalMb = (mi.totalMem / (1024L * 1024L)).toInt()

        return mapOf(
            "availableRamMb" to availMb,
            "totalRamMb" to totalMb,
            "isLowRamDevice" to mi.lowMemory
        )
    }

    /**
     * Reads Android 10+ (API 29+) hardware thermal throttling state.
     */
    fun getThermalStatus(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            when (pm?.currentThermalStatus) {
                PowerManager.THERMAL_STATUS_NONE -> "nominal"
                PowerManager.THERMAL_STATUS_LIGHT -> "fair"
                PowerManager.THERMAL_STATUS_MODERATE -> "serious"
                PowerManager.THERMAL_STATUS_SEVERE -> "severe"
                PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
                PowerManager.THERMAL_STATUS_EMERGENCY -> "emergency"
                PowerManager.THERMAL_STATUS_SHUTDOWN -> "shutdown"
                else -> "nominal"
            }
        } else {
            "nominal"
        }
    }

    /**
     * Checks network type (wifi, cellular, ethernet, none).
     */
    fun getNetworkStatus(): String {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "unknown"

        val activeNetwork = cm.activeNetwork ?: return "none"
        val caps = cm.getNetworkCapabilities(activeNetwork) ?: return "none"

        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
    }

    /**
     * Collects an aggregated device status snapshot for the Resource Governor.
     */
    fun getFullDeviceStatus(): Map<String, Any> {
        val battery = getBatteryInfo()
        val memory = getMemoryInfo()
        val thermal = getThermalStatus()
        val network = getNetworkStatus()

        return mapOf(
            "batteryLevel" to (battery["batteryLevel"] ?: 0.85f),
            "isCharging" to (battery["isCharging"] ?: false),
            "availableRamMb" to (memory["availableRamMb"] ?: 4096),
            "totalRamMb" to (memory["totalRamMb"] ?: 8192),
            "isLowRamDevice" to (memory["isLowRamDevice"] ?: false),
            "thermalState" to thermal,
            "networkType" to network,
            "cpuLoadFraction" to 0.15f
        )
    }

    /**
     * Emits a system notification with an update from an autonomous agent loop.
     */
    fun showNotification(channelId: String, notificationId: Int, title: String, content: String) {
        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        }
    }

    /**
     * Triggers haptic feedback.
     */
    fun vibrate(durationMs: Long = 200) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibratorManager?.defaultVibrator?.vibrate(
                VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        } else {
            @Suppress("DEPRECATION")
            val v = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            @Suppress("DEPRECATION")
            v?.vibrate(durationMs)
        }
    }
}
