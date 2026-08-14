import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Il gestore del task va registrato prima che il lancio dell'app termini,
    // altrimenti BGTaskScheduler rifiuta l'identificatore. L'identificatore e'
    // lo stesso dichiarato in Info.plist e usato da background_sync.dart.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "kickly-notification-poll-unique",
      earliestBeginInSeconds: 900
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
