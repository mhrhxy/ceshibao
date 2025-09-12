import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/utils/shared_preferences_util.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/config/constant_param.dart';
import 'package:flutter_mall/model/login_model.dart';
import 'package:flutter_mall/main_tab.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/language_provider.dart';
import 'forgotPassword.dart';
import 'forgotAccount.dart';
/// 登录页面（完整版：Logo和标语在背景图内，Logo居中偏右）
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

  // 布局参数：标签更窄、输入框更宽
  final double _labelWidth = 60; // 标签宽度（原70，已缩小）
  final double _inputHorizontalMargin = 40; // 输入区左右边距（原50，已缩小）
  final double _logoRightPadding = 30; // Logo和标语的右侧内边距（控制居中偏右位置）

  @override
  void initState() {
    super.initState();
    // 测试数据（可根据需求删除）
    _accountController.text = "bms";
    _passwordController.text = "1234567";
  }

  @override
  void dispose() {
    // 释放控制器资源
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 账号密码登录核心逻辑（接口请求+结果处理）
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

      // 4. 调用登录接口（使用项目封装的HttpUtil）
      Response result = await HttpUtil.post(
        loginDataUrl, // 配置文件中定义的登录接口地址
        data: loginParams,
      );

      // 5. 解析接口返回（按LoginModel模型处理）
      LoginModel loginModel = LoginModel.fromJson(result.data);
      if (loginModel.code == 200 && loginModel.token.isNotEmpty) {
        // 登录成功：存储token+跳转到首页（清除登录页栈）
        await SharedPreferencesUtil.saveString(token, loginModel.token);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainTab()),
            (route) => false,
          );
        }
      } else {
        // 登录失败：显示错误信息
        if (mounted) {
          _showToast(context, 
            loginModel.msg.isNotEmpty ? loginModel.msg : AppLocalizations.of(context)!.translate('login_failed')
          );
        }
      }
    } catch (e) {
      // 6. 异常处理（网络错误/解析错误等）
      if (mounted) {
        String errorMsg = e is DioError
            ? AppLocalizations.of(context)!.translate('network_error')
            : AppLocalizations.of(context)!.translate('login_exception');
        _showToast(context, errorMsg);
      }
    } finally {
      // 7. 隐藏加载状态（无论成功/失败都执行）
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }

  /// 通用提示弹窗（SnackBar）
  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // 成功（验证码发送）显示绿色，其他显示红色
        backgroundColor: message.contains(AppLocalizations.of(context)!.translate('verify_code_sent'))
            ? Colors.green
            : Colors.redAccent,
        duration: const Duration(seconds: 2), // 显示时长
        behavior: SnackBarBehavior.floating, // 悬浮样式（不占底部空间）
      ),
    );
  }

  /// 通用输入行组件（统一账号/密码输入框样式）
  Widget _buildInputRow({
    required String labelText,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false, // 是否隐藏输入（密码用）
    TextInputType keyboardType = TextInputType.text, // 键盘类型
    required bool enabled, // 是否可输入
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 标签（固定宽度）
        SizedBox(
          width: _labelWidth,
          child: Text(
            labelText,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 10), // 标签与输入框间距
        // 输入框（占满剩余宽度）
        Expanded(
          child: SizedBox(
            height: 50, // 固定输入框高度
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(), // 边框样式
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // 内边距
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 多语言配置（根据项目需求使用）
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        color: Colors.white, // 页面整体背景色
        child: Column(
          children: [
            // ---------------------- 1. 顶部背景图区域（含Logo和标语） ----------------------
            Container(
              // 背景图配置（覆盖整个顶部区域）
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('images/bjttb.png'), // 背景图路径
                  fit: BoxFit.cover, // 铺满容器且保持比例（避免拉伸）
                ),
              ),
              // 用Padding确保Logo和标语在背景图内，且有合理边距
              padding: EdgeInsets.only(
                top: 50, // 顶部边距（与返回按钮对齐）
                right: _logoRightPadding, // 右侧边距（控制居中偏右）
                bottom: 30, // 底部边距（与表单区域分隔）
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // 子组件右对齐（实现居中偏右）
                children: [
                  // 返回按钮（白色图标，适配背景图）
                  Align(
                    alignment: Alignment.topLeft, // 返回按钮单独靠左
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 0, 0, 0), size: 24),
                        onPressed: () => Navigator.pop(context), // 返回上一页
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // 返回按钮与Logo间距
                  // Logo（居中偏右，与标语对齐）
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

            const SizedBox(height: 20), // 顶部背景图与表单间距（可调整）

            // ---------------------- 2. 登录表单区域（保持原有样式） ----------------------
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: _inputHorizontalMargin, // 左右边距（控制输入框宽度）
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
                    enabled: !_isLoginLoading, // 加载时不可输入
                  ),
                  const SizedBox(height: 20), // 账号与密码输入框间距

                  // 密码输入行（隐藏输入内容）
                  _buildInputRow(
                    labelText: loc.translate('password'),
                    controller: _passwordController,
                    hintText: loc.translate('input_password_hint'),
                    obscureText: true, // 隐藏密码
                    enabled: !_isLoginLoading,
                  ),

                  const SizedBox(height: 20), // 密码输入框与辅助按钮间距

                  // 辅助按钮区（忘记密码/忘记账号，靠右对齐）
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 16.0, // 按钮之间的水平间距
                      runSpacing: 4.0, // 按钮换行时的垂直间距
                      children: [
                        TextButton(
                          onPressed: _isLoginLoading ? null : () {
                           Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ForgotPassword()),
                          );
                          }, // 加载时不可点击
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            loc.translate('forgot_password'),
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoginLoading ? null : () {
                             Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ForgotAccount()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            loc.translate('forgot_account'),
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30), // 辅助按钮与登录按钮间距

                  // 登录按钮（黄色背景，圆角样式）
                  InkWell(
                    onTap: _isLoginLoading ? null : _submitLoginData, // 加载时不可点击
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity, // 占满父容器宽度
                      height: 50, // 固定高度
                      decoration: BoxDecoration(
                        color: _isLoginLoading ? Colors.grey[300] : const Color.fromARGB(255, 243, 215, 53),
                        borderRadius: BorderRadius.circular(25), // 圆角（25px）
                      ),
                      child: _isLoginLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) // 加载动画
                          : Text(
                              loc.translate('login'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20), // 登录按钮底部间距
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}