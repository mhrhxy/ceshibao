import UIKit
import Flutter
import webview_flutter_wkwebview // 导入 WebView 依赖

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let webViewPlugin = WebViewFlutterPlugin()
    webViewPlugin.setup(with: controller.flutterEngine) // 注册 WebView 插件
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}