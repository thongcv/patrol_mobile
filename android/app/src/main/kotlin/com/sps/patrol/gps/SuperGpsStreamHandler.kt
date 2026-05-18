package com.sps.patrol.gps

import android.content.Context
import io.flutter.plugin.common.EventChannel

class SuperGpsStreamHandler(private val appContext: Context) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (events == null) return
        // onListen có thể gọi lại trước onCancel — gỡ sink cũ để không rò listener.
        eventSink?.let { SuperGpsLocationEngine.removeListener(it) }
        eventSink = events
        val options = SuperGpsStreamOptions.fromArguments(arguments)
        SuperGpsLocationEngine.addListener(appContext, events, options)
    }

    override fun onCancel(arguments: Any?) {
        eventSink?.let { SuperGpsLocationEngine.removeListener(it) }
        eventSink = null
    }
}
