import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'main_tab.dart';
///
/// 欢迎页面(启动页)
///
class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  @override
  void initState() {
    super.initState();
    //延迟3秒执行
    Future.delayed(const Duration(seconds: 3), () {
      //跳转至应用首页
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
      // ignore: use_build_context_synchronously
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const MainTab(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        // decoration: const BoxDecoration(
        //   color: Colors.white,
        // ),
        // padding: const EdgeInsets.all(50.0),
        alignment: Alignment.center,
        child: Image.asset(
          "images/shopping_cart.png",
          width: 200.w,
          height: 105.h,
          fit: BoxFit.contain,
        ));
  }
}
