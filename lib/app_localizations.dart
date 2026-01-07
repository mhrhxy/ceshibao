import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> _localizedStrings = {};

  Future<void> load() async {
    try {
      // 重点：确保路径正确（根据你的实际文件位置调整）
      String jsonString = await rootBundle.loadString('i18n/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      if (kDebugMode) {
        print('加载失败（${locale.languageCode}）：$e'); // 打印错误路径
      }
    }
  }

  String translate(String key) => _localizedStrings[key] ?? key;
  bool containsKey(String key) => _localizedStrings.containsKey(key);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'ko', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  // 关键：返回true，允许Locale变化时重新加载
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}