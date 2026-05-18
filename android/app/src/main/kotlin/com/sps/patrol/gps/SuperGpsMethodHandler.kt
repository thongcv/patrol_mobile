package com.sps.patrol.gps

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SuperGpsMethodHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentPosition" -> {
                val enableBarometer = call.argument<Boolean>("enableBarometer") ?: false
                SuperGpsLocationEngine.getCurrentPosition(
                    context.applicationContext,
                    enableBarometer,
                    result,
                )
            }
            "isBarometerSupported" -> {
                val supported = SuperGpsLocationEngine.isBarometerHardwareSupported(
                    context.applicationContext,
                )
                result.success(supported)
            }
            else -> result.notImplemented()
        }
    }
}
