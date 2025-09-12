// 新建 language_provider.dart
import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('zh'); // 默认中文

  Locale get currentLocale => _currentLocale;

  // 切换到韩文
  void setKorean() {
    _currentLocale = const Locale('ko');
    notifyListeners(); // 通知UI更新
  }

  // 切换到中文
  void setChinese() {
    _currentLocale = const Locale('zh');
    notifyListeners();
  }
    // 切换到英文
  void setEnglish() {
    _currentLocale = const Locale('en');
    notifyListeners();

  }
}