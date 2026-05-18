import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let gpsStreamChannel = "sps/super_gps_stream"
  private let gpsMethodChannel = "sps/super_gps"
  private let gpsStreamHandler = SuperGpsStreamHandler()
  private let gpsMethodHandler = SuperGpsMethodHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    FlutterMethodChannel(
      name: gpsMethodChannel,
      binaryMessenger: messenger
    ).setMethodCallHandler(gpsMethodHandler.handle)

    FlutterEventChannel(
      name: gpsStreamChannel,
      binaryMessenger: messenger
    ).setStreamHandler(gpsStreamHandler)
  }
}
