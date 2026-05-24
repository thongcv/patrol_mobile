package com.sps.patrol

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    companion object {
        /** Must match [PatrolBackgroundService.notificationChannelId]. */
        const val PATROL_TRACK_NOTIFICATION_CHANNEL_ID = "sps_patrol_track"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePatrolTrackNotificationChannel()
    }

    private fun ensurePatrolTrackNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
                as? NotificationManager ?: return
        if (manager.getNotificationChannel(PATROL_TRACK_NOTIFICATION_CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(
            PATROL_TRACK_NOTIFICATION_CHANNEL_ID,
            "Patrol tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Location tracking while patrol is active"
        }
        manager.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }
}
