import 'package:flutter/material.dart';
import 'login.dart';
import 'register.dart';
import 'main_tab.dart';
class Loginto extends StatelessWidget {
  const Loginto({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 顶部区域：使用背景图替换原有的渐变背景
          Expanded(
            flex: 1,
            child: Container(
              // 使用背景图替代渐变
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/bjttb.png'), // 背景图路径
                  fit: BoxFit.cover, // 图片填充方式，cover表示铺满容器且保持比例
                ),
              ),
            ),
          ),
          
          // 中间内容区：logo和标语（保持不变）
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'images/logo.png',
                width: 300,
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              
              Text(
                '“半价直购的智能消费者的开始',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          // 中间空白区域（保持不变）
          const Spacer(flex: 2),
          
          // 底部按钮区（保持不变）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KakaoTalk登录按钮
                ElevatedButton(
                  onPressed: () {
                    // KakaoTalk登录逻辑
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.chat_bubble_outline, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        '카카오톡으로 계속하기',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Naver登录按钮
                ElevatedButton(
                  onPressed: () {
                    // Naver登录逻辑
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'N',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '네이버로 계속하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // 底部操作区
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        // 跳转到login页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Login()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '이메일로 로그인',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: Colors.grey,
                    ),
                    TextButton(
                      onPressed: () {
                        // 邮箱注册逻辑
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Register()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '이메일로 가입',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: Colors.grey,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // 跳转到首页
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MainTab()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 236, 82, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        '돌리보기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 应用入口
void main() {
  runApp(const MaterialApp(
    title: '登录页面',
    home: Loginto(),
    debugShowCheckedModeBanner: false,
  ));
}
    