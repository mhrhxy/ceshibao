import 'package:flutter/material.dart';
import 'dingbudaohang.dart'; 

///
/// 比价页面
///

///
class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
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
