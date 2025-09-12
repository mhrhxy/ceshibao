import 'package:flutter/material.dart';
import 'bottom_navigation_bar.dart'; // 引入底部导航配置

/// 底部导航主页面
class MainTab extends StatefulWidget {
  const MainTab({super.key});

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> {
  int _bottomNavigationIndex = 0; // 底部导航选中索引

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_bottomNavigationIndex], // 根据索引切换页面
      // 关键：将 context 传递给 _bottomNavigationBar 方法
      bottomNavigationBar: _bottomNavigationBar(context), 
    );
  }

  // 修复：添加 BuildContext 参数，用于传递给 items()
  BottomNavigationBar _bottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      // 修复：调用 items() 时传入 context（获取国际化需要）
      items: items(context), 
      currentIndex: _bottomNavigationIndex,
      onTap: (flag) {
        setState(() {
          _bottomNavigationIndex = flag; // 更新选中索引
        });
      },
      selectedItemColor: Colors.blue, // 选中时颜色
      unselectedItemColor: Colors.grey, // 未选中时颜色
      selectedLabelStyle: const TextStyle(
        color: Colors.blue,
        fontSize: 12,
      ),
      unselectedLabelStyle: const TextStyle(
        color: Colors.grey,
        fontSize: 12,
      ),
      type: BottomNavigationBarType.fixed, // 固定所有导航项（避免溢出）
    );
  }
}