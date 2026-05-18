package com.sps.patrol.gps

internal data class SuperGpsStreamOptions(
    val updateIntervalMs: Long = DEFAULT_UPDATE_INTERVAL_MS,
    val minUpdateIntervalMs: Long = DEFAULT_MIN_UPDATE_INTERVAL_MS,
    val minUpdateDistanceMeters: Float = DEFAULT_MIN_UPDATE_DISTANCE_METERS,
    val enableBarometer: Boolean = DEFAULT_ENABLE_BAROMETER,
) {
    companion object {
        const val DEFAULT_UPDATE_INTERVAL_MS = 700L
        const val DEFAULT_MIN_UPDATE_INTERVAL_MS = 500L
        const val DEFAULT_MIN_UPDATE_DISTANCE_METERS = 0f
        const val DEFAULT_ENABLE_BAROMETER = false

        fun fromArguments(arguments: Any?): SuperGpsStreamOptions {
            if (arguments !is Map<*, *>) return SuperGpsStreamOptions()

            return SuperGpsStreamOptions(
                updateIntervalMs = readLong(
                    arguments,
                    "updateIntervalMs",
                    DEFAULT_UPDATE_INTERVAL_MS,
                ),
                minUpdateIntervalMs = readLong(
                    arguments,
                    "minUpdateIntervalMs",
                    DEFAULT_MIN_UPDATE_INTERVAL_MS,
                ),
                minUpdateDistanceMeters = readFloat(
                    arguments,
                    "minUpdateDistanceMeters",
                    DEFAULT_MIN_UPDATE_DISTANCE_METERS,
                ),
                enableBarometer = readBool(
                    arguments,
                    "enableBarometer",
                    DEFAULT_ENABLE_BAROMETER,
                ),
            )
        }

        private fun readBool(map: Map<*, *>, key: String, default: Boolean): Boolean {
            val value = map[key] ?: return default
            return when (value) {
                is Boolean -> value
                else -> default
            }
        }

        private fun readLong(map: Map<*, *>, key: String, default: Long): Long {
            val value = map[key] ?: return default
            return when (value) {
                is Int -> value.toLong()
                is Long -> value
                is Double -> value.toLong()
                is Float -> value.toLong()
                else -> default
            }
        }

        private fun readFloat(map: Map<*, *>, key: String, default: Float): Float {
            val value = map[key] ?: return default
            return when (value) {
                is Int -> value.toFloat()
                is Long -> value.toFloat()
                is Double -> value.toFloat()
                is Float -> value
                else -> default
            }
        }
    }
}
