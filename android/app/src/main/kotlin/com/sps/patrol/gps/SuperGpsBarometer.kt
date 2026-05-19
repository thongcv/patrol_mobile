package com.sps.patrol.gps

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.pow

/**
 * Barometer (TYPE_PRESSURE) — cùng công thức ISA với [barometric_altitude.dart].
 */
internal class SuperGpsBarometer {
    @Volatile
    var latestAltitudeM: Double? = null
        private set

    private var sensorManager: SensorManager? = null
    private var pressureSensor: Sensor? = null
    private var listener: SensorEventListener? = null
    private var active = false
    private var firstReadingLatch: CountDownLatch? = null
    private val firstReadingSignaled = AtomicBoolean(false)

    val hasHardwareSupport: Boolean
        get() = pressureSensor != null

    val isActive: Boolean
        get() = active

    fun bind(context: Context) {
        if (sensorManager != null) return
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = sm
        pressureSensor = sm.getDefaultSensor(Sensor.TYPE_PRESSURE)
    }

    @Synchronized
    fun start(context: Context) {
        bind(context.applicationContext)
        val sensor = pressureSensor ?: return
        if (active) return

        firstReadingLatch = CountDownLatch(1)
        firstReadingSignaled.set(false)

        val sm = sensorManager ?: return
        val eventListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                val altitude = altitudeMetersFromPressureHpa(event.values[0])
                if (altitude.isFinite()) {
                    latestAltitudeM = altitude
                    signalFirstReading()
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        listener = eventListener
        sm.registerListener(
            eventListener,
            sensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
        active = true
    }

    /**
     * Chờ mẫu áp suất đầu tiên sau [start]. Trả về ngay nếu đã có [latestAltitudeM].
     */
    fun awaitFirstReading(timeoutMs: Long = FIRST_READING_TIMEOUT_MS): Boolean {
        if (latestAltitudeM != null) return true
        val latch = firstReadingLatch ?: return false
        return try {
            latch.await(timeoutMs, TimeUnit.MILLISECONDS)
            latestAltitudeM != null
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            latestAltitudeM != null
        }
    }

    @Synchronized
    fun stop() {
        val sm = sensorManager
        val eventListener = listener
        if (sm != null && eventListener != null) {
            sm.unregisterListener(eventListener)
        }
        listener = null
        active = false
        firstReadingLatch = null
    }

    @Synchronized
    fun reset() {
        stop()
        latestAltitudeM = null
        firstReadingSignaled.set(false)
    }

    private fun signalFirstReading() {
        if (!firstReadingSignaled.compareAndSet(false, true)) return
        firstReadingLatch?.countDown()
    }

    companion object {
        const val FIRST_READING_TIMEOUT_MS = 800L
        private const val SEA_LEVEL_PRESSURE_HPA = 1013.25

        fun altitudeMetersFromPressureHpa(pressureHpa: Float): Double {
            if (!pressureHpa.isFinite() || pressureHpa <= 0f) return Double.NaN
            return 44330.0 * (1.0 - (pressureHpa / SEA_LEVEL_PRESSURE_HPA).toDouble()
                .pow(0.1902632))
        }
    }
}
