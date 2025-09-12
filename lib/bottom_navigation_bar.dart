import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/cart.dart';
import 'package:flutter_mall/categories.dart';
import 'package:flutter_mall/home.dart';
import 'package:flutter_mall/mine.dart';
import 'package:flutter_mall/favorite.dart';

/// 底部导航页-切换页面
final pages = [
  const Categories(), // 搜索
  const Cart(),       // 比价
  const Home(),       // 首页
  const Favorite(),   // 收藏
  const Mine(),       // 我的
];

/// 底部导航-图标和国际化文字定义
List<BottomNavigationBarItem> items(BuildContext context) {
  // 获取国际化实例
  final loc = AppLocalizations.of(context);
  
  return [
    BottomNavigationBarItem(
      icon: const Icon(Icons.search_sharp),
      label: loc.translate('search') // 搜索
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.turned_in_not),
      label: loc.translate('price_comparison') // 比价
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      label: loc.translate('home') // 首页
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.star_outline),
      label: loc.translate('collect') // 收藏
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person_outline),
      label: loc.translate('mine') // 我的
    ),
  ];
}
