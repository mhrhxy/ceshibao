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
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
// 导入商品详情页面
import 'productdetails.dart';
import 'self_product_details.dart';

// 程序的入口点
void main() async {
  // 确保Flutter的绑定被初始化，以便在主函数中使用Flutter的特性
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化SharedPreferences
  await SharedPreferencesUtil.init();
    // 获取 Key Hash 并打印
// 打印 Key Hash
  // 启动应用程序
  KakaoSdk.init(nativeAppKey: 'ca610cfd836872a2e451f79a1be06cf6');
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
                supportedLocales: const [
                  Locale('zh'),
                  Locale('ko'),
                  Locale('en'),
                ],
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                  useMaterial3: true,
                ),
                home: const Welcome(),
                onGenerateRoute: (settings) {
                  print('Route requested: ${settings.name}'); // 打印请求的路径
  
                  // 判断是否是深度链接，路径是否包含 'xq'
                  if (settings.name?.startsWith('/xq') ?? false) {
                    String fullUrl = settings.name!; // 获取完整的 URL
                    Uri uri = Uri.parse(
                      'couzikapp://' + fullUrl,
                    ); // 拼接成完整的URL，防止uri解析出错

                    // 打印 uri 路径，看看是否正确解析
                    print('uri.pathSegments: ${uri.pathSegments}'); // 打印路径段

                    // 处理商品详情页路径
                    if (uri.host == '' && uri.pathSegments.isNotEmpty) {
                      String productId =
                          uri.pathSegments.last; // 获取最后一个路径段作为 productId
                      print('跳转到商品详情页面，productId: $productId');
                      return MaterialPageRoute(
                        builder:
                            (context) =>
                                ProductDetails(id: productId), // 跳转到商品详情页
                      );
                    }
                  }

                  // 判断是否是 'zyxq' 类型的深度链接
                  if (settings.name?.startsWith('/zyxq') ?? false) {
                    String fullUrl = settings.name!; // 获取完整的 URL
                    Uri uri = Uri.parse(
                      'couzikapp://' + fullUrl,
                    ); // 拼接成完整的URL，防止uri解析出错

                    // 打印 uri 路径，看看是否正确解析
                    print('uri.pathSegments: ${uri.pathSegments}'); // 打印路径段

                    // 处理自营商品详情页路径
                    if (uri.host == '' && uri.pathSegments.isNotEmpty) {
                      String productId =
                          uri.pathSegments.last; // 获取最后一个路径段作为 productId
                      print('跳转到自营商品详情页面，productId: $productId');
                      return MaterialPageRoute(
                        builder:
                            (context) =>
                                SelfProductDetails(id: productId), // 跳转到自营商品详情页
                      );
                    }
                  }
                  // 默认返回 null，表示没有匹配到深度链接，跳到默认页面
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
