import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_mall/model/toast_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'register.dart';
import 'main_tab.dart';
import 'language_provider.dart';
import 'app_localizations.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart'; // 引入Naver登录插件
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart'; // 引入Kakao登录插件
import 'package:url_launcher/url_launcher.dart';
import 'utils/http_util.dart';
import 'utils/shared_preferences_util.dart';
import 'config/service_url.dart';
import 'config/constant_param.dart';
class Loginto extends StatelessWidget {
  const Loginto({super.key});

  /// 获取并保存最大订单限额接口（登录成功后调用）
  static Future<void> _fetchAndSaveMaxOrderLimit(String token) async {
    try {
      // 设置请求头（携带登录成功的token）
      HttpUtil.dio.options.headers['Authorization'] = 'Bearer $token';
      
      // 调用最大订单限额接口
      var result = await HttpUtil.get(maxOrderPurchaseLimitUrl);
      
      if (result.data['code'] == 200) {
        // 保存最大订单限额到本地
        String maxLimit = result.data['msg'] ?? '0';
        await SharedPreferencesUtil.saveString('maxOrderLimit', maxLimit);
      }
    } catch (e) {
      // 异常处理
      print('获取最大订单限额失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 顶部区域：使用背景图替换原有的渐变背景
          Expanded(
            flex: 1,
            child: Container(
              // 使用背景图替代渐变
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/bjttb.png'), // 背景图路径
                  fit: BoxFit.cover, // 图片填充方式，cover表示铺满容器且保持比例
                ),
              ),
            ),
          ),
          
          // 中间内容区：logo和标语（保持不变）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'images/logo.png',
                width: 300.w,
                height: 100.h,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 10.h),
              
              Text(
                '“${AppLocalizations.of(context).translate('smart_consumer_start')}',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          // 中间空白区域（保持不变）
          const Spacer(flex: 2),
          
          // 底部按钮区（保持不变）
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0.w, vertical: 30.0.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 语言切换按钮
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, child) {
                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16.w,
                      runSpacing: 8.h,
                      children: [
                        TextButton(
                          onPressed: () => languageProvider.setChinese(),
                          child: Text(
                            '中文',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: languageProvider.currentLocale.languageCode == 'zh' 
                                  ? Colors.blue 
                                  : Colors.black87,
                              fontWeight: languageProvider.currentLocale.languageCode == 'zh' 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => languageProvider.setEnglish(),
                          child: Text(
                            'English',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: languageProvider.currentLocale.languageCode == 'en' 
                                  ? Colors.blue 
                                  : Colors.black87,
                              fontWeight: languageProvider.currentLocale.languageCode == 'en' 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => languageProvider.setKorean(),
                          child: Text(
                            '한국어',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: languageProvider.currentLocale.languageCode == 'ko' 
                                  ? Colors.blue 
                                  : Colors.black87,
                              fontWeight: languageProvider.currentLocale.languageCode == 'ko' 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 16.h),
                
                // KakaoTalk登录按钮
                ElevatedButton(
                  onPressed: () async {
                    // KakaoTalk登录逻辑
                   try {
                    final authToken = await UserApi.instance.loginWithKakaoTalk();
                        print("Kakao login success");

                        print("Access Token: ${authToken.accessToken}");
                        // 获取用户信息
                        final user = await UserApi.instance.me();
                        print("User info: ${user.kakaoAccount?.profile?.nickname}");

                         final loginParams = {
                               "id":user.id,//第三方ID
                                "kakaoAccount":{
                                    "email":user.kakaoAccount?.email,//邮箱
                                    "profile":{
                                        "nickname":user.kakaoAccount?.profile?.nickname//昵称
                                    }
                                }
                          };
                          
                          // 调用naver登录接口
                          final loginResponse = await HttpUtil.post(kakaoLoginUrl, data: loginParams);
                          
                          if (loginResponse.data['code'] == 200) {
                            // 登录成功，获取token
                            final loginToken = loginResponse.data['token'];
                            
                            // 存储token
                            await SharedPreferencesUtil.saveString(token, loginToken);
                            
                            // 获取并保存最大订单限额
                            await _fetchAndSaveMaxOrderLimit(loginToken);
                            
                            // 跳转到首页
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const MainTab()),
                              (route) => false,
                            );
                          } else {
                            // 登录失败
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('登录失败/未绑定第三方账号')),
                            );
                          }

                      } catch (error) {
                        print('카카오계정으로 로그인 실패 $error');
                      }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.black),
                      SizedBox(width: 8.w),
                      Text(
                        AppLocalizations.of(context).translate('continue_with_kakao'),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                
                // Naver登录按钮
                ElevatedButton(
                  onPressed: () async {
                        try {
                         final result = await FlutterNaverLogin.logIn();
                          //获取当前有效的 accessToken
                          final accessToken = await FlutterNaverLogin.getCurrentAccessToken();
                          
                          // 准备登录接口参数
                          final loginParams = {
                            "id": result.account?.id,
                            "nickname": result.account?.nickname,
                            "email": result.account?.email,
                            "mobile": result.account?.mobile?.replaceAll('-', ''),//手机号
                            "accessToken": accessToken.accessToken,
                          };
                          
                          // 调用naver登录接口
                          final loginResponse = await HttpUtil.post(naverLoginUrl, data: loginParams);
                          
                          if (loginResponse.data['code'] == 200) {
                            // 登录成功，获取token
                            final loginToken = loginResponse.data['token'];
                            
                            // 存储token
                            await SharedPreferencesUtil.saveString(token, loginToken);
                            
                            // 获取并保存最大订单限额
                            await _fetchAndSaveMaxOrderLimit(loginToken);
                            
                            // 跳转到首页
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const MainTab()),
                              (route) => false,
                            );
                          } else {
                            // 登录失败
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('登录失败/未绑定第三方账号')),
                            );
                          }

                        } catch (e) {
                          // 如果登录失败，你可以显示错误提示给用户
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('登录失败，请重试！$e')),
                          );
                        }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'N',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        AppLocalizations.of(context).translate('continue_with_naver'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                
                // 底部操作区
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    TextButton(
                      onPressed: () {
                        // 跳转到login页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Login()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('login_with_email'),
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    Text('', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
                    TextButton(
                      onPressed: () {
                        // 邮箱注册逻辑
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Register()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('register_with_email'),
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    Text('', style: TextStyle(color: Colors.grey, fontSize: 14.sp)),
                    ElevatedButton(
                      onPressed: () {
                        // 跳转到首页
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MainTab()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 236, 82, 26),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('back'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// 应用入口
void main() {
  runApp(const MaterialApp(
    title: '登录页面',
    home: Loginto(),
    debugShowCheckedModeBanner: false,
  ));
}
