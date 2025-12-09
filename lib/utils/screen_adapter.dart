import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 屏幕适配工具类
class ScreenAdapter {
  /// 设计稿宽度（默认375pt）
  static double designWidth = 375.0;
  
  /// 设计稿高度（默认812pt）
  static double designHeight = 812.0;
  
  /// 设备像素比
  static double get devicePixelRatio => ui.window.devicePixelRatio;
  
  /// 屏幕尺寸
  static Size get screenSize => ui.window.physicalSize / devicePixelRatio;
  
  /// 屏幕宽度
  static double get screenWidth => screenSize.width;
  
  /// 屏幕高度
  static double get screenHeight => screenSize.height;
  
  /// 状态栏高度
  static double get statusBarHeight => MediaQueryData.fromWindow(ui.window).padding.top;
  
  /// 底部安全区域高度
  static double get bottomBarHeight => MediaQueryData.fromWindow(ui.window).padding.bottom;
  
  /// 是否为横屏
  static bool get isLandscape => screenWidth > screenHeight;
  
  /// 是否为平板（简单判断：最短边大于600）
  static bool get isTablet => screenSize.shortestSide >= 600;
  
  /// 宽度适配：将设计稿上的宽度转换为实际设备宽度
  static double width(double width) {
    return width * screenWidth / designWidth;
  }
  
  /// 高度适配：将设计稿上的高度转换为实际设备高度
  static double height(double height) {
    return height * screenHeight / designHeight;
  }
  
  /// 字体大小适配
  static double fontSize(double fontSize) {
    // 字体大小适配可以考虑视口宽度，避免在大屏幕上字体过大
    double scale = screenWidth / designWidth;
    return fontSize * scale;
  }
  
  /// 根据设备尺寸获取响应式边距
  static EdgeInsets get padding {
    if (isTablet) {
      return EdgeInsets.all(20);
    }
    return EdgeInsets.all(10);
  }
  
  /// 根据设备尺寸获取响应式边距
  static EdgeInsets get horizontalPadding {
    return EdgeInsets.symmetric(horizontal: width(15));
  }
}