import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/language_provider.dart';
import 'package:flutter_mall/provider/cart_model.dart';
import 'package:flutter_mall/provider/counter.dart';
import 'package:flutter_mall/utils/shared_preferences_util.dart';
import 'package:flutter_mall/welcome.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'config/nav_key.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 导入订单页面
import 'Myorder.dart';
// 导入商品详情页面
import 'productdetails.dart';

// 程序的入口点
void main() async {
  // 确保Flutter的绑定被初始化，以便在主函数中使用Flutter的特性
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化SharedPreferences
  await SharedPreferencesUtil.init();
  // 启动应用程序
  runApp(const MyApp());
}

// MyApp类是应用的根部件
class MyApp extends StatelessWidget {
  // 构造函数，使用super.key来初始化StatelessWidget的key属性
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用MultiProvider来管理应用的状态
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => Counter()),
            ChangeNotifierProvider(create: (_) => CartModel()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return MaterialApp(
                navigatorKey: NavKey.navKey,
                title: 'couzik',
                locale: languageProvider.currentLocale, // 动态设置当前语言
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('zh'), Locale('ko'),Locale('en')],
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                  useMaterial3: true,
                ),
                home: const Welcome(),
                // 配置深度链接处理
                onGenerateRoute: (settings) {
                  // 处理深度链接
                  if (settings.name?.startsWith('flutterappxm://') ?? false) {
                    String fullUrl = settings.name!;
                    Uri uri = Uri.parse(fullUrl);
                    
                    if (uri.scheme == 'flutterappxm') {
                      if (uri.host == 'detail') {
                        // 处理商品详情链接，格式为flutterappxm://detail/{id}
                        String productId = uri.path.replaceFirst('/', '');
                        // 直接打开商品详情页，但确保返回时有页面可回
                        return MaterialPageRoute(
                          builder: (context) => ProductDetails(id: productId),
                        );
                      } else if (uri.host == 'orders') {
                        // 处理订单页面链接
                        return MaterialPageRoute(
                          builder: (context) => const Myorder(),
                        );
                      }
                    }
                  }
                  
                  // 默认路由处理
                  return null;
                },
              );
            },
          ),
        );
      },
    );
  }
}
