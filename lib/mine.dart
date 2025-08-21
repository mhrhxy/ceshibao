import 'package:flutter/material.dart';

///
/// 我的页面

///
class Mine extends StatefulWidget {
  const Mine({super.key});

  @override
  State<Mine> createState() => _MineState();
}

class _MineState extends State<Mine> {
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
      width: MediaQuery.of(context).size.width,
      // 直接返回空的 Container，去掉所有原有组件
      child: Container(),
    ),
  );
}
}
