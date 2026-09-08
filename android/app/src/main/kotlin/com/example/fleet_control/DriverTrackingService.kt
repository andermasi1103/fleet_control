package com.example.fleet_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.Executors

/** Android-owned FGS. It never hosts a Flutter engine or persists credentials. */
class DriverTrackingService : Service() {
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private val senderExecutor = Executors.newSingleThreadExecutor()
    private val sendLock = Any()

    private var isSending = false
    private var pendingLocation: Location? = null
    private var lastSentLocation: Location? = null
    private var lastSentAtMillis: Long? = null
    private var sessionToken: String? = null
    private var backendApiBaseUrl: String? = null
    private var profile = TrackingProfile.AVAILABLE
    private var foregroundStarted = false
    private var terminalError = false

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.locations.forEach(::receiveLocation)
            }
        }
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> start(intent)
            ACTION_UPDATE_PROFILE -> updateProfile(intent)
            ACTION_STOP -> stopSelf()
        }
        // Never recreate without runtime-only credentials after process death.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        fusedLocationClient.removeLocationUpdates(locationCallback)
        senderExecutor.shutdownNow()
        synchronized(sendLock) {
            pendingLocation = null
            isSending = false
        }
        if (!terminalError) TrackingServiceStatusStore.write(this, "idle")
        debug("tracking: service stopped")
        super.onDestroy()
    }

    private fun start(intent: Intent) {
        val token = intent.getStringExtra(EXTRA_SESSION_TOKEN)
        val baseUrl = intent.getStringExtra(EXTRA_BACKEND_API_BASE_URL)
        val requestedProfile = TrackingProfile.from(intent.getStringExtra(EXTRA_PROFILE))
        if (token.isNullOrBlank() || !isSafeBaseUrl(baseUrl) || requestedProfile == null) {
            failStart("invalid_configuration")
            return
        }
        if (!hasLocationPermission() || !hasNotificationPermission()) {
            failStart("permission_denied")
            return
        }
        sessionToken = token
        backendApiBaseUrl = baseUrl
        profile = requestedProfile
        terminalError = false
        try {
            promoteToForeground()
            requestLocationUpdates()
            isRunning = true
            TrackingServiceStatusStore.write(this, "active", profile.wireValue)
            debug("tracking: service started")
        } catch (_: Exception) {
            failStart("service_start_failed")
        }
    }

    private fun updateProfile(intent: Intent) {
        val requestedProfile = TrackingProfile.from(intent.getStringExtra(EXTRA_PROFILE)) ?: return
        if (!foregroundStarted || sessionToken.isNullOrBlank() || backendApiBaseUrl.isNullOrBlank()) return
        profile = requestedProfile
        lastSentLocation = null
        lastSentAtMillis = null
        requestLocationUpdates()
        TrackingServiceStatusStore.write(this, "active", profile.wireValue)
        debug("tracking: profile updated")
    }

    private fun failStart(message: String) {
        terminalError = true
        TrackingServiceStatusStore.write(this, "error", profile.wireValue, message)
        stopSelf()
    }

    private fun promoteToForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        foregroundStarted = true
    }

    private fun requestLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        val configuration = profile.configuration
        val request = LocationRequest.Builder(configuration.priority, configuration.intervalMillis)
            .setMinUpdateIntervalMillis(configuration.intervalMillis)
            .setMinUpdateDistanceMeters(configuration.distanceMeters)
            .setMaxUpdateDelayMillis(configuration.intervalMillis)
            .build()
        fusedLocationClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
    }

    private fun receiveLocation(location: Location) {
        if (!isValid(location)) return
        debug("tracking: location callback received")
        synchronized(sendLock) {
            if (isSending) {
                pendingLocation = newer(pendingLocation, location)
                return
            }
            if (!shouldSend(location)) return
            isSending = true
        }
        senderExecutor.execute { send(location) }
    }

    private fun send(location: Location) {
        when (postLocation(location)) {
            SendResult.SENT -> {
                debug("tracking: location sent")
                val next = synchronized(sendLock) {
                    lastSentLocation = location
                    lastSentAtMillis = System.currentTimeMillis()
                    pendingLocation.also {
                        pendingLocation = null
                        isSending = false
                    }
                }
                next?.let(::receiveLocation)
            }
            SendResult.UNAUTHORIZED -> {
                terminalError = true
                TrackingServiceStatusStore.write(this, "error", profile.wireValue, "session_invalid")
                debug("tracking: service stopped after unauthorized response")
                stopSelf()
            }
            SendResult.FAILED -> {
                debug("tracking: location send failed")
                synchronized(sendLock) {
                    pendingLocation = newer(pendingLocation, location)
                    isSending = false
                }
            }
        }
    }

    private fun postLocation(location: Location): SendResult {
        val token = sessionToken ?: return SendResult.UNAUTHORIZED
        val baseUrl = backendApiBaseUrl ?: return SendResult.UNAUTHORIZED
        return try {
            val connection = (URL(endpointFor(baseUrl)).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = NETWORK_TIMEOUT_MILLIS
                readTimeout = NETWORK_TIMEOUT_MILLIS
                doOutput = true
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
            }
            connection.outputStream.bufferedWriter(Charsets.UTF_8).use { it.write(payloadFor(location).toString()) }
            val status = connection.responseCode
            (if (status in 200..299) connection.inputStream else connection.errorStream)?.close()
            connection.disconnect()
            when (status) {
                401, 403 -> SendResult.UNAUTHORIZED
                in 200..299 -> SendResult.SENT
                else -> SendResult.FAILED
            }
        } catch (_: Exception) {
            SendResult.FAILED
        }
    }

    private fun payloadFor(location: Location): JSONObject = JSONObject().apply {
        put("latitude", location.latitude)
        put("longitude", location.longitude)
        put("accuracy", if (location.hasAccuracy() && location.accuracy >= 0) location.accuracy else JSONObject.NULL)
        put("speed", if (location.hasSpeed() && location.speed >= 0) location.speed else JSONObject.NULL)
        put("heading", if (location.hasBearing() && location.bearing >= 0 && location.bearing < 360) location.bearing else JSONObject.NULL)
        put("captured_at", utcTimestamp(location.time))
    }

    private fun isValid(location: Location): Boolean {
        if (!location.latitude.isFinite() || !location.longitude.isFinite() ||
            location.latitude !in -90.0..90.0 || location.longitude !in -180.0..180.0 ||
            !location.hasAccuracy() || location.accuracy < 0 ||
            location.accuracy > profile.configuration.maximumAccuracyMeters
        ) return false
        val age = System.currentTimeMillis() - location.time
        return age in -MAX_FUTURE_SKEW_MILLIS..MAX_LOCATION_AGE_MILLIS
    }

    private fun shouldSend(location: Location): Boolean {
        val previous = lastSentLocation ?: return true
        val previousSentAt = lastSentAtMillis ?: return true
        val elapsed = System.currentTimeMillis() - previousSentAt
        val configuration = profile.configuration
        if (elapsed < configuration.minimumSendIntervalMillis) return false
        if (previous.distanceTo(location) >= configuration.minimumSendDistanceMeters) return true
        return elapsed >= configuration.maximumSendIntervalMillis
    }

    private fun newer(first: Location?, second: Location): Location =
        if (first == null || second.time >= first.time) second else first

    private fun endpointFor(baseUrl: String) = "${baseUrl.trimEnd('/')}/api/driver/location"

    private fun isSafeBaseUrl(baseUrl: String?): Boolean {
        val value = baseUrl ?: return false
        return try {
            val url = URL(value)
            url.host.isNotBlank() && (url.protocol == "https" || url.protocol == "http")
        } catch (_: Exception) {
            false
        }
    }

    private fun hasLocationPermission() =
        ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun hasNotificationPermission() =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, "MasiTrack — Seguimiento de flota", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("MasiTrack")
            .setContentText("Ubicación activa durante tu jornada")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun utcTimestamp(millis: Long) = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.format(Date(millis))

    private fun debug(message: String) {
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            Log.d(TAG, message)
        }
    }

    private enum class SendResult { SENT, UNAUTHORIZED, FAILED }

    private enum class TrackingProfile(val wireValue: String, val configuration: TrackingConfiguration) {
        AVAILABLE("available", TrackingConfiguration(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 45_000, 75f, 100f, 45_000, 120_000, 25f)),
        ACTIVE_TRIP("activeTrip", TrackingConfiguration(Priority.PRIORITY_HIGH_ACCURACY, 12_000, 20f, 50f, 12_000, 45_000, 10f));

        companion object {
            fun from(value: String?) = entries.firstOrNull { it.wireValue == value }
        }
    }

    private data class TrackingConfiguration(
        val priority: Int,
        val intervalMillis: Long,
        val distanceMeters: Float,
        val maximumAccuracyMeters: Float,
        val minimumSendIntervalMillis: Long,
        val maximumSendIntervalMillis: Long,
        val minimumSendDistanceMeters: Float,
    )

    companion object {
        const val ACTION_START = "com.example.fleet_control.tracking.START"
        const val ACTION_UPDATE_PROFILE = "com.example.fleet_control.tracking.UPDATE_PROFILE"
        const val ACTION_STOP = "com.example.fleet_control.tracking.STOP"
        const val EXTRA_SESSION_TOKEN = "sessionToken"
        const val EXTRA_BACKEND_API_BASE_URL = "backendApiBaseUrl"
        const val EXTRA_PROFILE = "profile"
        const val NOTIFICATION_CHANNEL_ID = "masitrack_driver_tracking"
        const val NOTIFICATION_ID = 1201
        const val NETWORK_TIMEOUT_MILLIS = 15_000
        const val MAX_LOCATION_AGE_MILLIS = 120_000L
        const val MAX_FUTURE_SKEW_MILLIS = 10_000L
        const val TAG = "MasiTrackTracking"
        @Volatile
        var isRunning = false
        val SUPPORTED_PROFILES = setOf("available", "activeTrip")
    }
}
