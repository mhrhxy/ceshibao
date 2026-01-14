import 'package:flutter/material.dart';
import 'bottom_navigation_bar.dart';
import 'loginto.dart';
import 'cartadd.dart';
class MainTab extends StatefulWidget {
  final int initialIndex; // 初始选中的页面索引
  
  const MainTab({super.key, this.initialIndex = 1}); // 默认选中首页

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> {
  late int _selectedIndex; // 使用late初始化

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // 使用传入的初始索引
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 底部导航切换的页面内容
          pages[_selectedIndex],

          // 右下角悬浮按钮（白色背景、黑色图标）
          Positioned(
            bottom: 20, // 距离底部20px
            right: 20,  // 距离右侧20px
            child: Column(
              mainAxisSize: MainAxisSize.min, // 最小化列高度
              children: [
                // 加号按钮
                _buildFloatingButton(
                  color: Colors.white,
                  icon: Icons.add,
                  onPressed: () {
                     Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Loginto()),
                        );
                  },
                ),
                const SizedBox(height: 12), // 按钮间距

                // 购物车按钮（无红色消息提示）
                _buildFloatingButton(
                  color: Colors.white,
                  icon: Icons.shopping_cart,
                  onPressed: () {
                     Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Cart()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),

      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        items: buildBottomNavItems(context), // 使用配置好的导航项
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // 支持5个导航项时需设置
        selectedItemColor: Colors.blue,      // 选中项颜色
        unselectedItemColor: Colors.grey,    // 未选中项颜色
        showUnselectedLabels: true,          // 显示未选中项的文字
        onTap: (index) {
          // 点击底部导航项时更新选中索引
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }

  // 构建悬浮按钮（白色背景、黑色图标、圆形带阴影）
  Widget _buildFloatingButton({
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color, // 白色背景
        borderRadius: BorderRadius.circular(28), // 圆形
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2), // 阴影向下偏移，增强立体感
          ),
        ],
        border: Border.all(color: Colors.grey.shade200), // 浅灰色边框（可选，增强区分度）
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black, size: 28), // 黑色图标
        onPressed: onPressed,
        padding: EdgeInsets.zero, // 去除IconButton默认内边距
      ),
    );
  }
}