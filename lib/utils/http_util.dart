import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mall/config/constant_param.dart';
import 'package:flutter_mall/language_provider.dart';
import 'package:flutter_mall/login.dart';
import '../dingbudaohang.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/nav_key.dart';

/// http工具类（修复post方法参数必填问题）
class HttpUtil {
  static Dio? _dio;

  static Dio get dio {
    if (_dio == null) {
      BaseOptions options = BaseOptions(
        baseUrl: "http://192.168.0.120:8080/",
        connectTimeout: const Duration(milliseconds: 5000),
        receiveTimeout: const Duration(milliseconds: 5000),
      );

      _dio = Dio(options);

      _dio!.interceptors.add(InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (kDebugMode) {
            print("\n");
            print("\n");
            print("========================请求数据===================");
            print("url=${options.uri.toString()}");
            print("params=${options.data}");
          }
          return handler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          if (kDebugMode) {
            print("\n");
            print("\n");
            print("========================响应数据===================");
            print("code=${response.statusCode}");
            print("response=${response.data}");
            print("==================================================");
            print("\n");
            print("\n");
            print("\n");
          }
          return handler.next(response);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) {
          if (kDebugMode) {
            print("\n");
            print("\n");
            print("========================错误数据===================");
            print("code=${e.response?.statusCode}");
            print("message=${e.response?.statusMessage}");
            print("data=${e.response?.data}");
            print("==================================================");
            print("\n");
            print("\n");
            print("\n");
          }
          if (e.response?.statusCode == 401) {
            Navigator.of(NavKey.navKey.currentState!.context).push(
              MaterialPageRoute(builder: (context) => const Login()),
            );
            return;
          }
          return handler.next(e);
        },
      ));
    }
    return _dio!;
  }

  static String _getLangFromProvider() {
    if (NavKey.navKey.currentContext != null) {
      LanguageProvider langProvider = Provider.of<LanguageProvider>(
        NavKey.navKey.currentContext!,
        listen: false,
      );
      return langProvider.currentLocale.languageCode;
    }
    return 'zh';
  }

  static Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> header = <String, dynamic>{};
      header["Authorization"] = prefs.getString(token);
      
      String currentLang = _getLangFromProvider();
      switch (currentLang) {
        case 'ko':
          header["Accept-Language"] = 'ko';
          break;
        case 'en':
          header["Accept-Language"] = 'en';
          break;
        default:
          header["Accept-Language"] = 'zh';
      }

      Response response = await dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: header),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // 关键修复：将queryParameters改为可选参数并设置默认值
  static Future<Response> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, Object> queryParameters = const {}, // 改为可选参数，默认空Map
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> header = <String, dynamic>{};
      header["Authorization"] = prefs.getString(token);
      
      String currentLang = _getLangFromProvider();
      switch (currentLang) {
        case 'ko':
          header["Accept-Language"] = 'ko';
          break;
        case 'en':
          header["Accept-Language"] = 'en';
          break;
        default:
          header["Accept-Language"] = 'zh';
      }

      Response response = await dio.post(
        path,
        data: jsonEncode(data),
        queryParameters: queryParameters, // 添加queryParameters参数传递
        options: Options(contentType: 'application/json', headers: header),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Response> postForm(String path, {Map<String, dynamic>? data}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> header = <String, dynamic>{};
      header["Authorization"] = prefs.getString(token);
      
      String currentLang = _getLangFromProvider();
      switch (currentLang) {
        case 'ko':
          header["Accept-Language"] = 'ko';
          break;
        case 'en':
          header["Accept-Language"] = 'en-';
          break;
        default:
          header["Accept-Language"] = 'zh';
      }

      Response response = await dio.post(
        path,
        queryParameters: data,
        options: Options(headers: header),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// PUT请求方法
  static Future<Response> put(String path, {Map<String, dynamic>? data}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> header = <String, dynamic>{};
      header["Authorization"] = prefs.getString(token);
      
      String currentLang = _getLangFromProvider();
      switch (currentLang) {
        case 'ko':
          header["Accept-Language"] = 'ko';
          break;
        case 'en':
          header["Accept-Language"] = 'en';
          break;
        default:
          header["Accept-Language"] = 'zh';
      }

      Response response = await dio.put(
        path,
        data: jsonEncode(data),
        options: Options(
          contentType: 'application/json',
          headers: header,
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
    