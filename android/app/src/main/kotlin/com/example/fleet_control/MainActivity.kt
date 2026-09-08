package com.example.fleet_control

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createOrdersNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTracking" -> startTracking(call, result)
                    "stopTracking" -> {
                        stopService(Intent(this, DriverTrackingService::class.java))
                        TrackingServiceStatusStore.write(this, "idle")
                        result.success(currentTrackingStatus())
                    }
                    "updateProfile" -> updateProfile(call, result)
                    "getStatus" -> result.success(currentTrackingStatus())
                    else -> result.notImplemented()
                }
            }
    }

    private fun startTracking(call: MethodCall, result: MethodChannel.Result) {
        val sessionToken = call.argument<String>("sessionToken")
        val backendApiBaseUrl = call.argument<String>("backendApiBaseUrl")
        val profile = call.argument<String>("profile")
        if (sessionToken.isNullOrBlank() || backendApiBaseUrl.isNullOrBlank() ||
            profile == null || profile !in DriverTrackingService.SUPPORTED_PROFILES
        ) {
            result.error("invalid_arguments", "Tracking configuration is invalid.", null)
            return
        }
        if (!hasLocationPermission()) {
            result.error("location_permission_denied", "Location permission is required.", null)
            return
        }
        if (!hasNotificationPermission()) {
            result.error("notifications_blocked", "Notification permission is required.", null)
            return
        }

        val intent = Intent(this, DriverTrackingService::class.java).apply {
            action = DriverTrackingService.ACTION_START
            putExtra(DriverTrackingService.EXTRA_SESSION_TOKEN, sessionToken)
            putExtra(DriverTrackingService.EXTRA_BACKEND_API_BASE_URL, backendApiBaseUrl)
            putExtra(DriverTrackingService.EXTRA_PROFILE, profile)
        }
        try {
            TrackingServiceStatusStore.write(this, "starting", profile)
            ContextCompat.startForegroundService(this, intent)
            result.success(TrackingServiceStatusStore.read(this))
        } catch (_: Exception) {
            TrackingServiceStatusStore.write(this, "error", profile, "service_start_failed")
            result.error("service_start_failed", "Unable to start tracking service.", null)
        }
    }

    private fun updateProfile(call: MethodCall, result: MethodChannel.Result) {
        val profile = call.argument<String>("profile")
        if (profile == null || profile !in DriverTrackingService.SUPPORTED_PROFILES) {
            result.error("invalid_arguments", "Tracking profile is invalid.", null)
            return
        }
        if (currentTrackingStatus()["status"] != "active") {
            result.success(currentTrackingStatus())
            return
        }
        TrackingServiceStatusStore.write(this, "active", profile)
        startService(Intent(this, DriverTrackingService::class.java).apply {
            action = DriverTrackingService.ACTION_UPDATE_PROFILE
            putExtra(DriverTrackingService.EXTRA_PROFILE, profile)
        })
        result.success(currentTrackingStatus())
    }

    private fun hasLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED

    private fun createOrdersNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            ORDERS_NOTIFICATION_CHANNEL_ID,
            "Pedidos MasiTrack",
            NotificationManager.IMPORTANCE_HIGH,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun currentTrackingStatus(): Map<String, String?> {
        val storedStatus = TrackingServiceStatusStore.read(this)["status"]
        if (!DriverTrackingService.isRunning && storedStatus != "error") {
            TrackingServiceStatusStore.write(this, "idle")
        }
        return TrackingServiceStatusStore.read(this)
    }

    private companion object {
        const val CHANNEL = "masitrack/driver_tracking"
        const val ORDERS_NOTIFICATION_CHANNEL_ID = "masitrack_orders"
    }
}
