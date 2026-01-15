import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/config/constant_param.dart';
import 'package:flutter_mall/language_provider.dart';
import 'package:flutter_mall/loginto.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/service_url.dart';
import '../config/nav_key.dart';

/// http工具类（修复post方法参数必填问题）
class HttpUtil {
  static Dio? _dio;

  static Dio get dio {
    if (_dio == null) {
      BaseOptions options = BaseOptions(
        baseUrl: baseUrl,
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
          
          // 检查业务响应中的错误码，即使HTTP状态码是200
          if (response.data != null) {
            try {
              Map<String, dynamic> responseData = response.data is String 
                  ? jsonDecode(response.data) 
                  : response.data;
              
              // 检查业务错误码
              if (responseData['code'] == 401 ||
                  responseData['code'] == 'UNAUTHORIZED' ||
                  responseData['msg']?.contains('认证失败') == true ||
                  responseData['message']?.contains('认证失败') == true) {
                
                if (kDebugMode) {
                  print("业务层面检测到token过期，执行处理逻辑...");
                }
                
                // 异步处理token过期
                Future.microtask(() {
                  _handleTokenExpired();
                });
                
                // 可以选择修改响应数据或者直接返回
                // response.data = {'code': 401, 'message': '登录已过期'}; 
              }
            } catch (e) {
              if (kDebugMode) {
                print("解析业务响应失败: $e");
              }
            }
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
            print("error type: ${e.type}");
            print("==================================================");
            print("\n");
            print("\n");
            print("\n");
          }
          
          // 强制处理所有401错误
          bool isTokenExpired = false;
          
          // 检查HTTP状态码
          if (e.response?.statusCode == 401) {
            isTokenExpired = true;
          }
          
          // 检查业务层面的错误码
          if (!isTokenExpired && e.response?.data != null) {
            try {
              Map<String, dynamic> responseData = e.response?.data is String 
                  ? jsonDecode(e.response!.data) 
                  : e.response!.data;
              
              print("解析到的业务响应: $responseData");
              
              if (responseData['code'] == 401 || 
                  responseData['code'] == 'UNAUTHORIZED' ||
                  responseData['msg']?.contains('认证失败') == true ||
                  responseData['message']?.contains('认证失败') == true) {
                isTokenExpired = true;
              }
            } catch (parseError) {
              if (kDebugMode) {
                print("解析响应数据失败: $parseError");
              }
            }
          }
          
          if (isTokenExpired) {
            print("检测到token过期，执行处理逻辑...");
            // 使用Future.microtask确保在当前事件循环后执行
            Future.microtask(() {
              _handleTokenExpired();
            });
            // 不调用handler.next(e)，中断错误传播
            handler.resolve(Response(requestOptions: e.requestOptions, data: e.response?.data));
            return;
          }
          
          return handler.next(e);
        },
      ));
    }
    return _dio!;
  }

  // 处理token过期
  static Future<void> _handleTokenExpired() async {
    try {
      print("开始处理token过期...");
      
      // 清除本地存储的过期token
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool tokenRemoved = await prefs.remove(token);
      bool passwordRemoved = await prefs.remove('password');
      
      if (kDebugMode) {
        print("清除token结果: $tokenRemoved");
        print("清除password结果: $passwordRemoved");
        print("当前是否有上下文: ${NavKey.navKey.currentState != null}");
      }
      
      // 显示登录过期提示（居中显示）
      if (NavKey.navKey.currentState != null) {
        BuildContext context = NavKey.navKey.currentState!.context;
        
        // 确保在UI线程中显示提示
        if (context.mounted) {
          // 使用原生AlertDialog实现居中提示
          await showDialog(
            context: context,
            barrierDismissible: false, // 点击外部不关闭
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('登录提示'),
                content: const Text('未登录，请先登录'),
                actions: [
                  TextButton(
                    onPressed: () {
                      // 关闭对话框并跳转登录页
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const Loginto()),
                      );
                    },
                    child: Text(AppLocalizations.of(dialogContext)?.translate('confirm') ?? '确定'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        // 如果没有上下文，直接跳转到登录页面
        if (kDebugMode) {
          print("没有获取到上下文，使用runApp重新启动应用到登录页");
        }
        // 这里可以考虑使用runApp重新启动应用到登录页
      }
    } catch (e) {
      if (kDebugMode) {
        print('处理token过期失败: $e');
        // 打印详细的错误信息
        print(e.toString());
      }
    }
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
          header["Accept-Language"] = 'zh-CN';
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

  // 关键修复：将queryParameters改为可选参数并设置默认值，并添加options参数支持
  // 修改data参数类型为dynamic以支持List类型
  static Future<Response> post(
    String path, {
    dynamic data, // 修改为dynamic类型以支持List<Map<String, dynamic>>
    Map<String, Object> queryParameters = const {}, // 改为可选参数，默认空Map
    Options? options, // 添加options参数支持
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

      // 合并用户传入的options和默认options
      Options requestOptions = options ?? Options();
      // 设置contentType默认值
      requestOptions.contentType = requestOptions.contentType ?? 'application/json';
      // 合并headers
      if (requestOptions.headers == null) {
        requestOptions.headers = header;
      } else {
        requestOptions.headers!.addAll(header);
      }

      // 如果data是FormData类型，不进行JSON编码，直接传递
      // 否则，将data转换为JSON格式
      dynamic requestData = data is FormData ? data : jsonEncode(data);
      
      Response response = await dio.post(
        path,
        data: requestData,
        queryParameters: queryParameters, // 添加queryParameters参数传递
        options: requestOptions,
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

  /// PUT请求方法 - 修改data参数类型为dynamic以支持List类型
  static Future<Response> put(String path, {dynamic data}) async {
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

  /// DELETE请求方法
  static Future<Response> del(String path, {Map<String, dynamic>? queryParameters}) async {
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

      Response response = await dio.delete(
        path,
        queryParameters: queryParameters,
        options: Options(headers: header),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
    