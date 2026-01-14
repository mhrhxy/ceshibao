import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'login.dart';
import 'register.dart';
import 'main_tab.dart';
import 'language_provider.dart';
import 'app_localizations.dart';
class Loginto extends StatelessWidget {
  const Loginto({super.key});

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
            padding: EdgeInsets.symmetric(horizontal: 24.0.w, vertical: 30.0.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 语言切换按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Row(
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
                            SizedBox(width: 16.w),
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
                            SizedBox(width: 16.w),
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
                  ],
                ),
                SizedBox(height: 16.h),
                
                // KakaoTalk登录按钮
                // ElevatedButton(
                //   onPressed: () {
                //     // KakaoTalk登录逻辑
                //   },
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.yellow,
                //     padding: EdgeInsets.symmetric(vertical: 16.h),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8.r),
                //     ),
                //     elevation: 0,
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       Icon(Icons.chat_bubble_outline, color: Colors.black),
                //       SizedBox(width: 8.w),
                //       Text(
                //         AppLocalizations.of(context).translate('continue_with_kakao'),
                //         style: TextStyle(
                //           color: Colors.black,
                //           fontSize: 16.sp,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                // SizedBox(height: 16.h),
                
                // // Naver登录按钮
                // ElevatedButton(
                //   onPressed: () {
                //     // Naver登录逻辑
                //   },
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.green,
                //     padding: EdgeInsets.symmetric(vertical: 16.h),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8.r),
                //     ),
                //     elevation: 0,
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       Text(
                //         'N',
                //         style: TextStyle(
                //           fontSize: 20.sp,
                //           fontWeight: FontWeight.bold,
                //           color: Colors.white,
                //         ),
                //       ),
                //       SizedBox(width: 8.w),
                //       Text(
                //         AppLocalizations.of(context).translate('continue_with_naver'),
                //         style: TextStyle(
                //           color: Colors.white,
                //           fontSize: 16.sp,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                // SizedBox(height: 32.h),
                
                // 底部操作区
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
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
                    VerticalDivider(
                      width: 1.w,
                      color: Colors.grey,
                    ),
                    TextButton(
                      onPressed: () {
                        // 邮箱注册逻辑
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Register()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
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
                    VerticalDivider(
                      width: 1.w,
                      color: Colors.grey,
                    ),
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
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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