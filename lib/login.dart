import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/utils/shared_preferences_util.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/config/constant_param.dart';
import 'package:flutter_mall/model/login_model.dart';
// 新增：用户信息模型（与账户信息页一致）
import 'package:flutter_mall/model/member_info_model.dart'; 
import 'package:flutter_mall/main_tab.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/language_provider.dart';
import 'forgotPassword.dart';
import 'forgotAccount.dart';
import 'register.dart';

/// 登录页面（完整版：登录成功后获取并保存用户信息）
class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // 账号密码输入控制器
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // 登录加载状态
  bool _isLoginLoading = false;

  // 布局参数
  final double _labelWidth = 60;
  final double _inputHorizontalMargin = 40;
  final double _logoRightPadding = 30;

  @override
  void initState() {
    super.initState();
    // 测试数据
    _accountController.text = "";
    _passwordController.text = "";
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 新增：获取最大订单限额接口（登录成功后调用）
  Future<void> _fetchAndSaveMaxOrderLimit(String token) async {
    try {
      // 设置请求头（携带登录成功的token）
      HttpUtil.dio.options.headers['Authorization'] = 'Bearer $token';
      
      // 调用最大订单限额接口
      Response result = await HttpUtil.get(maxOrderPurchaseLimitUrl);
      
      if (result.data['code'] == 200) {
        // 保存最大订单限额到本地
        String maxLimit = result.data['msg'] ?? '0';
        await SharedPreferencesUtil.saveString('maxOrderLimit', maxLimit);
      } else {
        // 获取最大订单限额失败（不阻断登录流程）
        if (mounted) {
          _showToast(
            context, 
            '获取最大订单限额失败：${result.data['msg']}'
          );
        }
      }
    } catch (e) {
      // 异常处理（网络错误等，不阻断登录）
      if (mounted) {
        _showToast(
          context, 
          '获取最大订单限额异常：${e.toString()}'
        );
      }
    }
  }

  /// 新增：获取用户信息接口（登录成功后调用）
  Future<void> _fetchAndSaveMemberInfo(String token) async {
    try {
      // 设置请求头（携带登录成功的token）
      HttpUtil.dio.options.headers['Authorization'] = 'Bearer $token';
      
      // 调用用户信息接口（memberinfo）
      Response result = await HttpUtil.get(memberinfo);
      
      if (result.data['code'] == 200) {
        // 解析用户信息
        MemberInfoModel memberInfo = MemberInfoModel.fromJson(result.data['data']);
        
        // 保存用户信息到本地（转为JSON字符串存储）
        await SharedPreferencesUtil.saveString(
          'member_info', 
          json.encode(memberInfo.toJson())
        );
      } else {
        // 获取用户信息失败（不阻断登录流程，仅提示）
        if (mounted) {
          _showToast(
            context, 
            AppLocalizations.of(context)!.translate('get_user_info_failed')
          );
        }
      }
    } catch (e) {
      // 异常处理（网络错误等，不阻断登录）
      if (mounted) {
        _showToast(
          context, 
          '${AppLocalizations.of(context)!.translate('network_error')}：${e.toString()}'
        );
      }
    }
  }

  /// 账号密码登录核心逻辑（新增：登录成功后调用用户信息接口）
  Future<void> _submitLoginData() async {
    // 1. 输入校验
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();
    
    if (account.isEmpty) {
      _showToast(context, AppLocalizations.of(context)!.translate('input_account_tip'));
      return;
    }
    if (password.isEmpty) {
      _showToast(context, AppLocalizations.of(context)!.translate('input_password_tip'));
      return;
    }

    // 2. 显示加载状态
    setState(() => _isLoginLoading = true);

    try {
      // 3. 组装登录参数
      Map<String, dynamic> loginParams = {
        "username": account,
        "password": password
      };

      // 4. 调用登录接口
      Response result = await HttpUtil.post(
        loginDataUrl,
        data: loginParams,
      );

      // 5. 解析登录结果
      LoginModel loginModel = LoginModel.fromJson(result.data);
      if (loginModel.code == 200 && loginModel.token.isNotEmpty) {
        // 登录成功：先保存token
        await SharedPreferencesUtil.saveString(token, loginModel.token);

        // 新增：调用用户信息接口并保存到本地
        await _fetchAndSaveMemberInfo(loginModel.token);
        
        // 新增：调用最大订单限额接口并保存到本地
        await _fetchAndSaveMaxOrderLimit(loginModel.token);

        // 跳转首页（清除登录页栈）
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainTab()),
            (route) => false,
          );
        }
      } else {
        // 登录失败：显示错误信息
        if (mounted) {
          _showToast(
            context, 
            loginModel.msg.isNotEmpty ? loginModel.msg : AppLocalizations.of(context)!.translate('login_failed')
          );
        }
      }
    } catch (e) {
      // 6. 异常处理
      if (mounted) {
        String errorMsg = e is DioError
            ? AppLocalizations.of(context)!.translate('network_error')
            : AppLocalizations.of(context)!.translate('login_exception');
        _showToast(context, errorMsg);
      }
    } finally {
      // 7. 隐藏加载状态
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }

  /// 通用提示弹窗
  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains(AppLocalizations.of(context)!.translate('verify_code_sent'))
            ? Colors.green
            : Colors.redAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 通用输入行组件
  Widget _buildInputRow({
    required String labelText,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required bool enabled,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(
            labelText,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 50,
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 60,
          leading: Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black, size: 24),
              onPressed: () {
                Navigator.pop(context);
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // 顶部背景图区域
            Container(
              width: double.infinity,
            decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/bjttb.png'),
                  fit: BoxFit.cover,
                ),
              ),
              padding: EdgeInsets.only(
                top: 50,
                bottom: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 返回按钮已移至AppBar
                  const SizedBox(height: 20),
                  // Logo和标语
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
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 登录表单区域
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: _inputHorizontalMargin,
                vertical: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 账号输入行
                  _buildInputRow(
                    labelText: loc.translate('account'),
                    controller: _accountController,
                    hintText: loc.translate('input_account_hint'),
                    enabled: !_isLoginLoading,
                  ),
                  const SizedBox(height: 20),

                  // 密码输入行
                  _buildInputRow(
                    labelText: loc.translate('password'),
                    controller: _passwordController,
                    hintText: loc.translate('input_password_hint'),
                    obscureText: true,
                    enabled: !_isLoginLoading,
                  ),

                  const SizedBox(height: 20),

                  // 辅助按钮区
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 16.0,
                      runSpacing: 4.0,
                      children: [
                        TextButton(
                          onPressed: _isLoginLoading ? null : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const Register()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            loc.translate('register'),
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoginLoading ? null : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ForgotAccount()),
                            );
                          },
                          child: Text(
                            loc.translate('forgot_account'),
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoginLoading ? null : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ForgotPassword()),
                            );
                          },
                          child: Text(
                            loc.translate('forgot_password'),
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 登录按钮
                  InkWell(
                    onTap: _isLoginLoading ? null : _submitLoginData,
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isLoginLoading ? Colors.grey[300] : const Color.fromARGB(255, 243, 215, 53),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _isLoginLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              loc.translate('login'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}