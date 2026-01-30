import UIKit
import Flutter
import webview_flutter_wkwebview // 导入 WebView 依赖
import KakaoSDKCommon // 导入 Kakao SDK 依赖
import flutter_naver_login // 导入 Naver 登录插件
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let webViewPlugin = WebViewFlutterPlugin()
    KakaoSDK.initSDK(appKey: "kakaoca610cfd836872a2e451f79a1be06cf6") // 初始化 Kakao SDK
    NaverLoginPlugin.register(with: controller.registrar(forPlugin: "flutter_naver_login")) // 注册 Naver 登录插件
    webViewPlugin.setup(with: controller.flutterEngine) // 注册 WebView 插件
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}