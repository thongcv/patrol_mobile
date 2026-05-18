package com.sps.patrol

import com.sps.patrol.gps.SuperGpsMethodHandler
import com.sps.patrol.gps.SuperGpsStreamHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val GPS_STREAM_CHANNEL = "sps/super_gps_stream"
        const val GPS_METHOD_CHANNEL = "sps/super_gps"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, GPS_STREAM_CHANNEL)
            .setStreamHandler(SuperGpsStreamHandler(applicationContext))

        MethodChannel(messenger, GPS_METHOD_CHANNEL)
            .setMethodCallHandler(SuperGpsMethodHandler(applicationContext))
    }
}
