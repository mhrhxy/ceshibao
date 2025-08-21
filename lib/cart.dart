import 'package:flutter/material.dart';


///
/// 购物车页面
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
    body: Container(
      color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
      width: MediaQuery.of(context).size.width,
      // 直接返回空的 Container，去掉所有原有组件
      child: Container(),
    ),
  );
}
}
