import Foundation

struct SuperGpsStreamOptions: Equatable {
    var updateIntervalMs: Int64 = 700
    var minUpdateIntervalMs: Int64 = 500
    var minUpdateDistanceMeters: Float = 0
    var enableBarometer: Bool = false

    static func from(arguments: Any?) -> SuperGpsStreamOptions {
        guard let map = arguments as? [String: Any] else {
            return SuperGpsStreamOptions()
        }

        return SuperGpsStreamOptions(
            updateIntervalMs: readInt64(map, key: "updateIntervalMs", default: 700),
            minUpdateIntervalMs: readInt64(map, key: "minUpdateIntervalMs", default: 500),
            minUpdateDistanceMeters: readFloat(map, key: "minUpdateDistanceMeters", default: 0),
            enableBarometer: readBool(map, key: "enableBarometer", default: false)
        )
    }

    private static func readBool(_ map: [String: Any], key: String, default defaultValue: Bool) -> Bool {
        guard let value = map[key] else { return defaultValue }
        return value as? Bool ?? defaultValue
    }

    private static func readInt64(_ map: [String: Any], key: String, default defaultValue: Int64) -> Int64 {
        guard let value = map[key] else { return defaultValue }
        if let intValue = value as? Int { return Int64(intValue) }
        if let intValue = value as? Int64 { return intValue }
        if let doubleValue = value as? Double { return Int64(doubleValue) }
        if let floatValue = value as? Float { return Int64(floatValue) }
        return defaultValue
    }

    private static func readFloat(_ map: [String: Any], key: String, default defaultValue: Float) -> Float {
        guard let value = map[key] else { return defaultValue }
        if let floatValue = value as? Float { return floatValue }
        if let doubleValue = value as? Double { return Float(doubleValue) }
        if let intValue = value as? Int { return Float(intValue) }
        if let intValue = value as? Int64 { return Float(intValue) }
        return defaultValue
    }
}
