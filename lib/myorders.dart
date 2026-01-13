import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dingbudaohang.dart'; 

/// 我的页面

class Myorder extends StatefulWidget {
  const Myorder({super.key});

  @override
  State<Myorder> createState() => _Myorders();
}

class _Myorders extends State<Myorder> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Container(
        color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            // 标题和返回按钮区域
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              height: 40.h,
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: Colors.black87,size: 16.w,),
                    onPressed: () {
                      Navigator.pop(context); // 返回上一页
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(), // 去除默认按钮大小限制
                  ),
                  // 标题
                   Text(
                    "我的订单",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            // 页面内容区域（可添加其他组件）
            Expanded(
              child: Container(
                // 这里可以添加我的页面的具体内容
                padding: const EdgeInsets.all(16),
                child: const Center(
                  child: Text("个人中心内容"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

