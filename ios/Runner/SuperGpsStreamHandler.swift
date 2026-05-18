import Flutter

final class SuperGpsStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        let options = SuperGpsStreamOptions.from(arguments: arguments)
        SuperGpsLocationEngine.shared.addListener(sink: events, options: options)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        SuperGpsLocationEngine.shared.removeAllListeners()
        eventSink = nil
        return nil
    }
}
