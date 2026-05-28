package com.sps.patrol

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    companion object {
        /** Must match [PatrolBackgroundService.notificationChannelId]. */
        const val PATROL_TRACK_NOTIFICATION_CHANNEL_ID = "sps_patrol_track"
        private const val TTS_CHANNEL = "patrol/tts"
    }

    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensurePatrolTrackNotificationChannel()
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        ttsReady = false
        super.onDestroy()
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text")?.trim().orEmpty()
                        val language = call.argument<String>("language") ?: "vi-VN"
                        if (text.isEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        speakNative(text, language, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun speakNative(text: String, languageTag: String, result: MethodChannel.Result) {
        val locale = Locale.forLanguageTag(languageTag.replace('_', '-'))
        val engine = textToSpeech
        if (engine != null && ttsReady) {
            engine.language = locale
            val utteranceId = "patrol_checkpoint_${System.currentTimeMillis()}"
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
            result.success(null)
            return
        }

        textToSpeech = TextToSpeech(applicationContext) { status ->
            if (status != TextToSpeech.SUCCESS) {
                result.error("TTS_INIT", "TextToSpeech init failed", null)
                return@TextToSpeech
            }
            ttsReady = true
            textToSpeech?.language = locale
            val utteranceId = "patrol_checkpoint_${System.currentTimeMillis()}"
            textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {}
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {}
            })
            textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
            result.success(null)
        }
    }
}
