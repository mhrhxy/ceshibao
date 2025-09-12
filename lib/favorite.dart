import 'package:flutter/material.dart';
import 'dingbudaohang.dart'; 

///
/// 收藏页面
///

///
class Favorite extends StatefulWidget {
  const Favorite({super.key});

  @override
  State<Favorite> createState() => _Favorite();
}

class _Favorite extends State<Favorite> {
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: const FixedActionTopBar(),
    body: Container(
      color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
      width: MediaQuery.of(context).size.width,
      // 直接返回空的 Container，去掉所有原有组件
      child: Container(),
    ),
  );
}
}
