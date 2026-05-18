import Flutter

final class SuperGpsMethodHandler: NSObject {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCurrentPosition":
            let args = call.arguments as? [String: Any]
            let enableBarometer = args?["enableBarometer"] as? Bool ?? false
            SuperGpsLocationEngine.shared.getCurrentPosition(
                enableBarometer: enableBarometer,
                result: result
            )
        case "isBarometerSupported":
            result(SuperGpsLocationEngine.shared.isBarometerHardwareSupported())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
