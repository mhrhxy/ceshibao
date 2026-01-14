import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/cart.dart';
import 'package:flutter_mall/categories.dart';
import 'package:flutter_mall/home.dart';
import 'package:flutter_mall/mine.dart';
import 'package:flutter_mall/favorite.dart';

// 页面数组（供MainTab切换）
final List<Widget> pages = const [
  Categories(), // 0：搜索页
  Cart(),       // 1：比价页
  Home(),       // 2：首页（默认选中）
  Favorite(),   // 3：收藏页
  Mine(),       // 4：我的页
];

// 底部导航项生成方法
List<BottomNavigationBarItem> buildBottomNavItems(BuildContext context) {
  final loc = AppLocalizations.of(context);
  return [
    BottomNavigationBarItem(
      icon: const Icon(Icons.search_sharp),
      label: loc.translate('search'),
    ),
    // BottomNavigationBarItem(
    //   icon: const Icon(Icons.turned_in_not),
    //   label: loc.translate('price_comparison'),
    // ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      label: loc.translate('home'),
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.star_outline),
      label: loc.translate('collect'),
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person_outline),
      label: loc.translate('mine'),
    ),
  ];
}