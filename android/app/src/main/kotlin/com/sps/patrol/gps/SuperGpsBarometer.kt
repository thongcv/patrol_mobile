package com.sps.patrol.gps

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
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

        val sm = sensorManager ?: return
        val eventListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event == null) return
                val altitude = altitudeMetersFromPressureHpa(event.values[0])
                if (altitude.isFinite()) {
                    latestAltitudeM = altitude
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

    @Synchronized
    fun stop() {
        val sm = sensorManager
        val eventListener = listener
        if (sm != null && eventListener != null) {
            sm.unregisterListener(eventListener)
        }
        listener = null
        active = false
    }

    @Synchronized
    fun reset() {
        stop()
        latestAltitudeM = null
    }

    companion object {
        private const val SEA_LEVEL_PRESSURE_HPA = 1013.25

        fun altitudeMetersFromPressureHpa(pressureHpa: Float): Double {
            if (!pressureHpa.isFinite() || pressureHpa <= 0f) return Double.NaN
            return 44330.0 * (1.0 - (pressureHpa / SEA_LEVEL_PRESSURE_HPA).toDouble()
                .pow(0.1902632))
        }
    }
}
