import 'package:flutter/material.dart';
import 'dingbudaohang.dart'; 
///
/// 商品分类页面
///

///
class Categories extends StatefulWidget {
  const Categories({super.key});

  @override
  State<Categories> createState() => _CategoriesState();
}

// 商品分类页面
class _CategoriesState extends State<Categories> {
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: const FixedActionTopBar(showLogo: false),
    body: Container(
      color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
      width: MediaQuery.of(context).size.width,
      // 直接返回空的 Container，去掉所有原有组件
      child: Container(),
    ),
  );
}
}
