import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/utils/shared_preferences_util.dart';
import './home.dart';
import 'config/constant_param.dart';
import 'model/login_model.dart';

///
/// 登录页面
///
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}
class _LoginState extends State<Login> {
  //用户名文本控制器
  final TextEditingController _usernameController = TextEditingController();
  //密码文本控制器
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    //初始化用户名和密码，便于测试
    _usernameController.text = "koobe";
    _passwordController.text = "123456";
  }

  //提交登录
  void _submitLoginData() async {
    //创建一个映射，用于存储用户名和密码
    Map<String, dynamic> loginMap = <String, dynamic>{};
    loginMap["account"] = _usernameController.value.text;
    loginMap["password"] = _passwordController.value.text;
    
    //通过HTTP POST请求提交登录数据
    Response result = await HttpUtil.post(loginDataUrl, data: loginMap);

    //将登录响应数据解析为LoginModel对象
    LoginModel loginModel = LoginModel.fromJson(result.data);

    //保存登录凭证token
    SharedPreferencesUtil.saveString(token, "${loginModel.data.tokenHead} ${loginModel.data.token}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Column(
          children: [
            const SizedBox(height: 150),
            Image.asset(
              "images/shopping_cart.png",
              width: 150,
              height: 105,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            const Text(
              "未注册的手机号登陆成功后将自动注册",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 28),
            Container(
              margin: const EdgeInsets.only(left: 50.0, right: 50),
              child: Column(
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      hintText: "手机号",
                      // prefixText: "+86",
                      // contentPadding: EdgeInsets.only(left: 16),
                    ),
                  ),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(hintText: "密码"),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                     onTap: ()  { // 注意添加 async 关键字
                      // 1. 先执行登录请求（需等待登录完成）
                      _submitLoginData(); 
                      // 2. 登录成功后，跳转到首页并清除之前的页面栈
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const Home()), // 替换为你的首页组件
                        (route) => false, // 清除所有历史页面
                      );
                    },
                    child: Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(int.parse('fa436a', radix: 16)).withAlpha(255),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '登录',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
