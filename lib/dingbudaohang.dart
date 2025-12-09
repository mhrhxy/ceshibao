import 'package:flutter/material.dart';
import 'settings.dart';
import 'utils/screen_adapter.dart';
import 'message.dart';
import 'main_tab.dart';

class FixedActionTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String logoAsset;
  final IconData firstIcon;
  final IconData secondIcon;
  final String firstRouteName;
  final String secondRouteName;
  final Color backgroundColor;
  final Color iconColor;
  final double elevation;
  final bool showDivider;
  final double barHeight;
  final bool showLogo;
  // 关键修改：将 title 改为可选参数（允许为 null，去掉 required）
  final Text? title;

  const FixedActionTopBar({
    super.key,
    this.logoAsset = "images/logo.png",
    this.firstIcon = Icons.search,
    this.secondIcon = Icons.shopping_cart,
    this.firstRouteName = "/search",
    this.secondRouteName = "/cart",
    this.backgroundColor = Colors.white,
    this.iconColor = Colors.black87,
    this.elevation = 0,
    this.showDivider = true,
    this.barHeight = 60,
    this.showLogo = true,
    this.title, // 这里去掉 required，变为可选参数
  });

  @override
  Widget build(BuildContext context) {
    // 获取状态栏高度并添加到导航栏中
    double statusBarHeight = ScreenAdapter.statusBarHeight;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: backgroundColor,
          padding: EdgeInsets.only(top: statusBarHeight),
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: [
                if (showLogo)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () {
                        // 点击logo返回底部导航栏页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainTab(),
                          ),
                        );
                      },
                      child: Image.asset(
                        logoAsset,
                        width: 120,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            color: Colors.red,
                          );
                        },
                      ),
                    ),
                  ),
                // 如果需要显示 title，可以在这里添加（可选）
                if (title != null) title!, // 非空时显示
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: iconColor,
                    size: 24,
                  ),
                  onPressed: () {
                    // 导入Message页面并跳转到消息页面
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Message(),
                      ),
                    );
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                IconButton(
                  icon: Icon(
                    Icons.brightness_7_outlined,
                    color: iconColor,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ],
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(barHeight + ScreenAdapter.statusBarHeight + (showDivider ? 0.5 : 0));
}