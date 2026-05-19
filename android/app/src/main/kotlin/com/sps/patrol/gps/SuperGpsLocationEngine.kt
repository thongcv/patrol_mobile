package com.sps.patrol.gps

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal object SuperGpsLocationEngine {
    /** Chấp nhận cache lastLocation nếu mới hơn 2 phút — trả về tức thì. */
    private const val FAST_CACHE_MAX_AGE_MS = 120_000L

    /** getCurrentLocation: dùng cache tới 60s, tối đa chờ GPS mới 1.5s. */
    private const val CURRENT_LOC_MAX_AGE_MS = 60_000L
    private const val CURRENT_LOC_MAX_WAIT_MS = 1_500L

    /** One-shot: cache nhanh chỉ khi accuracy đủ tốt (sau Kalman). */
    private const val ONE_SHOT_BEST_ACCURACY_M = 4f

    private val kalman = SuperGpsKalmanFilter()
    private val fixGate = SuperGpsFixQualityGate()
    private val barometer = SuperGpsBarometer()
    private val sinks = linkedSetOf<EventChannel.EventSink>()

    private var fusedClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null
    private var running = false
    private var streamOptions = SuperGpsStreamOptions()
    private var startGeneration = 0

    @Synchronized
    fun addListener(
        context: Context,
        sink: EventChannel.EventSink,
        options: SuperGpsStreamOptions = SuperGpsStreamOptions(),
    ) {
        val optionsChanged = streamOptions != options
        streamOptions = options
        sinks.add(sink)
        when {
            !running -> start(context.applicationContext)
            optionsChanged -> restartUpdates(context.applicationContext)
        }
    }

    @Synchronized
    fun removeListener(sink: EventChannel.EventSink) {
        sinks.remove(sink)
        if (sinks.isEmpty()) {
            stop()
        }
    }

    fun isBarometerHardwareSupported(context: Context): Boolean {
        barometer.bind(context.applicationContext)
        return barometer.hasHardwareSupport
    }

    fun getCurrentPosition(
        context: Context,
        enableBarometer: Boolean,
        result: MethodChannel.Result,
    ) {
        if (!hasFineLocation(context)) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }

        val appContext = context.applicationContext
        barometer.bind(appContext)
        val shouldRunBaro = enableBarometer && barometer.hasHardwareSupport
        val client = LocationServices.getFusedLocationProviderClient(context)

        if (shouldRunBaro) {
            if (!barometer.isActive) {
                barometer.start(appContext)
            }
            Thread {
                barometer.awaitFirstReading(SuperGpsBarometer.FIRST_READING_TIMEOUT_MS)
                Handler(Looper.getMainLooper()).post {
                    fetchCurrentPositionGps(client, shouldRunBaro, result)
                }
            }.start()
            return
        }

        fetchCurrentPositionGps(client, shouldRunBaro = false, result)
    }

    private fun fetchCurrentPositionGps(
        client: FusedLocationProviderClient,
        shouldRunBaro: Boolean,
        result: MethodChannel.Result,
    ) {
        synchronized(this) {
            if (!running) {
                kalman.reset()
                fixGate.reset()
            }
        }

        // 1) lastLocation — thường <50ms nếu app/OS đã có cache.
        client.lastLocation
            .addOnSuccessListener { cached ->
                if (cached != null &&
                    isLocationFresh(cached, FAST_CACHE_MAX_AGE_MS) &&
                    cached.accuracy <= ONE_SHOT_BEST_ACCURACY_M
                ) {
                    val payload = buildOneShotPayloadIfAccepted(
                        cached,
                        includeBarometer = shouldRunBaro,
                    )
                    if (payload != null) {
                        finishGetCurrentPosition(
                            shouldRunBaro,
                            result,
                            payload,
                        )
                        return@addOnSuccessListener
                    }
                }
                requestCurrentLocationBounded(client, cached, shouldRunBaro, result)
            }
            .addOnFailureListener {
                requestCurrentLocationBounded(client, null, shouldRunBaro, result)
            }
    }

    private fun finishGetCurrentPosition(
        stopBarometerAfter: Boolean,
        result: MethodChannel.Result,
        payload: Map<String, Any?>?,
    ) {
        if (stopBarometerAfter && !running) {
            barometer.stop()
        }
        result.success(payload)
    }

    private fun requestCurrentLocationBounded(
        client: FusedLocationProviderClient,
        staleFallback: Location?,
        stopBarometerAfter: Boolean,
        result: MethodChannel.Result,
    ) {
        val request = CurrentLocationRequest.Builder()
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .setMaxUpdateAgeMillis(CURRENT_LOC_MAX_AGE_MS)
            .setDurationMillis(CURRENT_LOC_MAX_WAIT_MS)
            .build()

        client.getCurrentLocation(request, CancellationTokenSource().token)
            .addOnSuccessListener { location ->
                val best = pickBestLocation(location, staleFallback)
                val payload = best?.let {
                    buildOneShotPayloadIfAccepted(
                        it,
                        includeBarometer = stopBarometerAfter,
                    )
                }
                if (payload != null) {
                    finishGetCurrentPosition(
                        stopBarometerAfter,
                        result,
                        payload,
                    )
                } else if (best != null) {
                    finishGetCurrentPosition(stopBarometerAfter, result, null)
                } else {
                    finishGetCurrentPosition(stopBarometerAfter, result, null)
                }
            }
            .addOnFailureListener { e ->
                if (staleFallback != null) {
                    val fallbackPayload = buildOneShotPayloadIfAccepted(
                        staleFallback,
                        includeBarometer = stopBarometerAfter,
                    )
                    finishGetCurrentPosition(
                        stopBarometerAfter,
                        result,
                        fallbackPayload,
                    )
                } else {
                    if (stopBarometerAfter && !running) {
                        barometer.stop()
                    }
                    result.error("GPS_ERROR", e.message ?: "getCurrentLocation failed", null)
                }
            }
    }

    private fun isLocationFresh(location: Location, maxAgeMs: Long): Boolean {
        val age = System.currentTimeMillis() - location.time
        return age in 0..maxAgeMs
    }

    private fun pickBestLocation(vararg locations: Location?): Location? {
        return locations.filterNotNull().minByOrNull { it.accuracy }
    }

    private fun buildOneShotPayloadIfAccepted(
        location: Location,
        includeBarometer: Boolean,
    ): Map<String, Any?>? {
        synchronized(this) {
            if (!fixGate.shouldAccept(location, SuperGpsFixQualityGate.FixSource.ONE_SHOT)) {
                return null
            }
            fixGate.noteAccepted(location)
        }
        return buildPayload(location, includeBarometer, applyKalman = true)
    }

    @Synchronized
    private fun start(context: Context) {
        if (running) return

        if (!hasFineLocation(context)) {
            emitError("PERMISSION_DENIED", "Location permission not granted")
            return
        }

        val client = LocationServices.getFusedLocationProviderClient(context)
        fusedClient = client
        kalman.reset()
        fixGate.reset()

        val appContext = context.applicationContext
        barometer.bind(appContext)
        val wantBaro = streamOptions.enableBarometer && barometer.hasHardwareSupport

        if (wantBaro) {
            barometer.reset()
            syncBarometer(appContext)
            val generation = ++startGeneration
            Thread {
                barometer.awaitFirstReading(SuperGpsBarometer.FIRST_READING_TIMEOUT_MS)
                Handler(Looper.getMainLooper()).post {
                    synchronized(this@SuperGpsLocationEngine) {
                        if (generation != startGeneration || sinks.isEmpty() || running) {
                            return@post
                        }
                        beginGpsStream(client)
                    }
                }
            }.start()
            return
        }

        syncBarometer(appContext)
        beginGpsStream(client)
    }

    @Synchronized
    private fun beginGpsStream(client: FusedLocationProviderClient) {
        if (running) return

        seedCachedLocations(client)

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            streamOptions.updateIntervalMs,
        )
            .setMinUpdateIntervalMillis(streamOptions.minUpdateIntervalMs)
            .setMinUpdateDistanceMeters(streamOptions.minUpdateDistanceMeters)
            .setMaxUpdateDelayMillis(0L)
            .setWaitForAccurateLocation(false)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation ?: return
                tryEmitLocation(location, SuperGpsFixQualityGate.FixSource.STREAM)
            }
        }
        locationCallback = callback

        try {
            client.requestLocationUpdates(
                request,
                callback,
                Looper.getMainLooper(),
            )
            running = true
        } catch (e: SecurityException) {
            emitError("PERMISSION_DENIED", e.message ?: "SecurityException")
            stopInternal()
        } catch (e: Exception) {
            emitError("GPS_ERROR", e.message ?: "Failed to start GPS")
            stopInternal()
        }
    }

    private fun seedCachedLocations(client: FusedLocationProviderClient) {
        client.lastLocation
            .addOnSuccessListener { location ->
                if (location != null) {
                    tryEmitLocation(location, SuperGpsFixQualityGate.FixSource.SEED_CACHE)
                }
            }

        val request = CurrentLocationRequest.Builder()
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .setMaxUpdateAgeMillis(30_000)
            .build()
        client.getCurrentLocation(request, CancellationTokenSource().token)
            .addOnSuccessListener { location ->
                if (location != null) {
                    tryEmitLocation(location, SuperGpsFixQualityGate.FixSource.SEED_CACHE)
                }
            }
    }

    @Synchronized
    private fun restartUpdates(context: Context) {
        stopInternal()
        kalman.reset()
        fixGate.reset()
        if (sinks.isNotEmpty()) {
            start(context)
        }
    }

    @Synchronized
    private fun stop() {
        stopInternal()
        kalman.reset()
        fixGate.reset()
    }

    private fun stopInternal() {
        startGeneration++
        val callback = locationCallback
        if (callback != null) {
            fusedClient?.removeLocationUpdates(callback)
        }
        locationCallback = null
        fusedClient = null
        running = false
        barometer.stop()
    }

    private fun syncBarometer(context: Context) {
        val appContext = context.applicationContext
        barometer.bind(appContext)
        if (streamOptions.enableBarometer && barometer.hasHardwareSupport) {
            barometer.start(appContext)
        } else {
            barometer.stop()
        }
    }

    private fun tryEmitLocation(location: Location, source: SuperGpsFixQualityGate.FixSource) {
        synchronized(this) {
            if (fixGate.shouldAccept(location, source)) {
                fixGate.noteAccepted(location)
                emitFilteredLocation(location)
                return
            }
            val fallback = fixGate.peekStreamFallbackLocation() ?: return
            fixGate.noteAccepted(fallback)
            emitFilteredLocation(fallback)
        }
    }

    private fun emitFilteredLocation(location: Location) {
        val includeBaro =
            streamOptions.enableBarometer && barometer.hasHardwareSupport
        val payload = buildPayload(location, includeBarometer = includeBaro)
        val snapshot = sinks.toList()
        for (sink in snapshot) {
            try {
                sink.success(payload)
            } catch (_: Exception) {
                // Sink có thể đã bị hủy.
            }
        }
    }

    private fun buildPayload(
        location: Location,
        includeBarometer: Boolean,
        applyKalman: Boolean = true,
    ): Map<String, Any?> {
        val (outLat, outLng) = if (applyKalman) {
            kalman.process(
                location.latitude,
                location.longitude,
                location.accuracy,
                location.speed.coerceAtLeast(0f),
                location.time,
            )
        } else {
            location.latitude to location.longitude
        }
        return locationToMap(location, outLat, outLng, includeBarometer)
    }

    private fun emitError(code: String, message: String) {
        val snapshot = sinks.toList()
        for (sink in snapshot) {
            try {
                sink.error(code, message, null)
            } catch (_: Exception) {
                // Bỏ qua.
            }
        }
    }

    private fun hasFineLocation(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun locationToMap(
        location: Location,
        filteredLat: Double,
        filteredLng: Double,
        includeBarometer: Boolean,
    ): Map<String, Any?> {
        val map = linkedMapOf<String, Any?>(
            "latitude" to filteredLat,
            "longitude" to filteredLng,
            "raw_latitude" to location.latitude,
            "raw_longitude" to location.longitude,
            "timestamp" to location.time,
            "accuracy" to location.accuracy.toDouble(),
            "altitude" to location.altitude,
            "heading" to location.bearing.toDouble(),
            "speed" to location.speed.toDouble(),
            "is_mocked" to isMocked(location),
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            map["altitude_accuracy"] = location.verticalAccuracyMeters.toDouble()
            map["speed_accuracy"] = location.speedAccuracyMetersPerSecond.toDouble()
            map["heading_accuracy"] = location.bearingAccuracyDegrees.toDouble()
        } else {
            map["altitude_accuracy"] = 0.0
            map["speed_accuracy"] = 0.0
            map["heading_accuracy"] = 0.0
        }

        map["barometer_supported"] = barometer.hasHardwareSupport
        map["barometric_altitude"] = if (includeBarometer) {
            barometer.latestAltitudeM
        } else {
            null
        }

        return map
    }

    @Suppress("DEPRECATION")
    private fun isMocked(location: Location): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            location.isFromMockProvider
        }
    }
}
