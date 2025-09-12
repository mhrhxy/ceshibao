import 'package:flutter/material.dart';

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

  // 新增：自定义导航栏高度（解决图片大小限制的核心）
  final double barHeight;
  final bool showLogo;
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
    this.barHeight = 60, // 增大导航栏高度（默认56→80）
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: backgroundColor,
          // 使用Container包裹，避免AppBar高度限制
          child: SizedBox(
            height: barHeight, // 应用自定义高度
            child: Row(
              children: [
                // 左侧Logo（无高度限制）
                if (showLogo) // 条件渲染：仅当showLogo为true时显示
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                const Spacer(), // 推到右侧
                // 右侧图标
                IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: iconColor,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pushNamed(context, firstRouteName),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                IconButton(
                  icon: Icon(
                    Icons.brightness_7_outlined,
                    color: iconColor,
                    size: 24,
                  ),
                  onPressed:
                      () => Navigator.pushNamed(context, secondRouteName),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        // 底部分割线
        if (showDivider) Container(height: 0.5, color: const Color(0xFFEEEEEE)),
      ],
    );
  }

  // 导航栏总高度 = 自定义高度 + 分割线高度
  @override
  Size get preferredSize =>
      Size.fromHeight(barHeight + (showDivider ? 0.5 : 0));
}
