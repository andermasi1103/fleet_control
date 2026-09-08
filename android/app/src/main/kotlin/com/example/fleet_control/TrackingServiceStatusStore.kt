package com.example.fleet_control

import android.content.Context

/** Stores only non-sensitive status for Flutter to read after a resume. */
object TrackingServiceStatusStore {
    private const val PREFERENCES = "masitrack.driver_tracking.status"
    private const val STATUS = "status"
    private const val PROFILE = "profile"
    private const val MESSAGE = "message"

    fun write(context: Context, status: String, profile: String? = null, message: String? = null) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(STATUS, status)
            .putString(PROFILE, profile)
            .putString(MESSAGE, message)
            .apply()
    }

    fun read(context: Context): Map<String, String?> {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        return mapOf(
            "status" to (preferences.getString(STATUS, "idle") ?: "idle"),
            "profile" to preferences.getString(PROFILE, null),
            "message" to preferences.getString(MESSAGE, null),
        )
    }
}
