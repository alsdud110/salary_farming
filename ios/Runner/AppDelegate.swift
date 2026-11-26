import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 홈 화면 위젯 데이터(lib/home_widget_sync.dart)를 공유 저장소에 쓰고 위젯을 다시 그린다.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SalaryWidget") else { return }
    FlutterMethodChannel(name: "salary_farming/widget", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "update", let json = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        UserDefaults(suiteName: "group.com.salaryfarming.app")?.set(json, forKey: "months")
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      }
  }
}
