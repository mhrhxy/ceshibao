import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'language_provider.dart';
import 'app_localizations.dart';
import 'myorders.dart';
import 'loginto.dart';
import 'dingbudaohang.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late EasyRefreshController _controller;
  int _count = 4;

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final loc = AppLocalizations.of(context);

    // 修复：使用公共方法containsKey检查key是否存在
    assert(() {
      if (!loc.containsKey('go_login')) {
        print('警告：语言文件缺少 key "go_login"');
      }
      if (!loc.containsKey('my_orders')) {
        print('警告：语言文件缺少 key "my_orders"');
      }
      return true;
    }());

    // 复用按钮样式
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Container(
        color: Colors.white,
        child: EasyRefresh(
          controller: _controller,
          onRefresh: () async {
            setState(() => _count = 6);
            _controller.finishRefresh();
            _controller.resetFooter();
          },
          onLoad: () async {
            await Future.delayed(const Duration(seconds: 3));
            if (!mounted) return;
            setState(() => _count += 2);
            _controller.finishLoad(
              _count >= 30 ? IndicatorResult.noMore : IndicatorResult.success,
            );
          },
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              // 语言切换按钮
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              languageProvider.currentLocale ==
                                      const Locale('zh')
                                  ? Colors.green
                                  : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => languageProvider.setChinese(),
                        child: const Text("中文"),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              languageProvider.currentLocale ==
                                      const Locale('ko')
                                  ? Colors.green
                                  : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => languageProvider.setKorean(),
                        child: const Text("한국어"),
                      ),
                      const SizedBox(width: 16),

                      // 英文切换按钮
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              languageProvider.currentLocale ==
                                      const Locale('en')
                                  ? Colors.green
                                  : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed:
                            () =>
                                languageProvider.setEnglish(), // 关键修复：调用英文切换方法
                        child: const Text("英文"),
                      ),
                    ],
                  ),
                ),
              ),

              // 登录页跳转按钮
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: buttonStyle,
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Loginto(),
                          ),
                        ),
                    child: Text(
                      loc.translate('go_login'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // 订单页跳转按钮
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: buttonStyle,
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Myorder(),
                          ),
                        ),
                    child: Text(
                      loc.translate('my_orders'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
