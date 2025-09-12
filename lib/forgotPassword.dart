import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/login.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/utils/shared_preferences_util.dart';

/// 忘记密码页面（分两步：1.邮箱验证 2.重置密码）
class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  // 1. 输入控制器（分步骤对应）
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verifyCodeController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();

  // 2. 状态控制变量
  bool _isLoading = false; // 全局加载状态（按钮/输入框禁用）
  bool _canGetVerifyCode = true; // 发送验证码按钮状态
  String _verifyCodeText = ""; // 验证码按钮文本（发送/倒计时）
  bool _isFirstStep = true; // 步骤标记：true=第一步（邮箱+验证码），false=第二步（重置密码）
  bool _isObscureNewPwd = true; // 新密码隐藏状态
  bool _isObscureConfirmPwd = true; // 确认密码隐藏状态
  bool _isFirstInit = true; // 国际化初始化标记
  String? _memberName; // 新增：存储接口返回的会员账户名

  // 3. 布局参数（完全复用登录/注册页，确保风格统一）
  final double _labelWidth = 60;
  final double _inputHorizontalMargin = 40;
  final double _logoRightPadding = 30;

  @override
  void initState() {
    super.initState();
    // 测试数据（可选删除）
    _emailController.text = "test@example.com";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次初始化国际化文本（避免initState依赖错误）
    if (_isFirstInit) {
      _verifyCodeText = AppLocalizations.of(context)!.translate('send_code') ;
      _isFirstInit = false;
    }
  }

  @override
  void dispose() {
    // 释放控制器资源
    _emailController.dispose();
    _verifyCodeController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  /// 4. 核心逻辑1：发送验证码（复用注册页逻辑，适配忘记密码场景）
  Future<void> _sendVerifyCode() async {
    final email = _emailController.text.trim();
    // 邮箱校验
    if (email.isEmpty) {
      _showToast(context, AppLocalizations.of(context)!.translate('input_email_tip'));
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showToast(context, AppLocalizations.of(context)!.translate('email_format_error')  );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 调用发送验证码接口（忘记密码场景的type，需与后端确认，这里假设为4）
      Response result = await HttpUtil.post(
        "$apisendemail?email=$email&type=3", // 复用验证码接口，type区分场景
        data: {},
      );

      if (result.data['code'] == 200) {
        // 发送成功：开始倒计时
        _showToast(context, result.data['msg'] ?? "验证码已发送", isSuccess: true);
        setState(() {
          _canGetVerifyCode = false;
          _verifyCodeText = AppLocalizations.of(context)!.translate('countdown_60s') ;
        });

        // 60秒倒计时逻辑
        int countdown = 60;
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (countdown == 0) {
            if (mounted) {
              setState(() {
                _verifyCodeText = AppLocalizations.of(context)!.translate('send_code');
                _canGetVerifyCode = true;
              });
            }
            timer.cancel();
            return;
          }
          if (mounted) {
            setState(() {
              countdown--;
              _verifyCodeText = "${AppLocalizations.of(context)!.translate('countdown_second') }"
                  .replaceAll("%s", countdown.toString());
            });
          }
        });
      } else {
        _showToast(context, result.data['msg'] );
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? AppLocalizations.of(context)!.translate('network_error') ?? "网络错误"
          : "发送异常，请重试";
      _showToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 5. 核心逻辑2：第一步「下一步」- 验证邮箱+验证码
  Future<void> _goToSecondStep() async {
    final email = _emailController.text.trim();
    final code = _verifyCodeController.text.trim();
    // 表单校验
    if (email.isEmpty) {
      _showToast(context, "请输入邮箱");
      return;
    }
    if (code.isEmpty) {
      _showToast(context, AppLocalizations.of(context)!.translate('input_verify_code_tip') );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 调用验证码验证接口（需后端提供，这里假设接口路径）
      Response result = await HttpUtil.post(
        verifyForgotCodeUrl, // 新增：在service_url.dart定义验证接口
        data: {
          "email": email,
          "type":'3',
          "code": code
        },
      );

      if (result.data['code'] == 200) {
        // 验证通过：存储会员名 + 切换到第二步
        setState(() {
          _isFirstStep = false;
          _memberName = result.data['msg']; // 关键修改：存储接口返回的会员账户名
          _verifyCodeController.clear(); // 清空验证码输入框（可选）
        });
      } else {
        _showToast(context, result.data['msg']);
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? "网络错误，请检查网络"
          : "验证异常，请重试";
      _showToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 6. 核心逻辑3：第二步「确认」- 提交新密码
  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final newPwd = _newPwdController.text.trim();
    final confirmPwd = _confirmPwdController.text.trim();
    // 密码校验
    if (newPwd.isEmpty) {
      _showToast(context, AppLocalizations.of(context)!.translate('input_password_tip') );
      return;
    }
    if (newPwd.length < 6) { // 密码长度校验（可根据需求调整）
      _showToast(context, "新密码长度不能少于6位");
      return;
    }
    if (confirmPwd.isEmpty) {
      _showToast(context, AppLocalizations.of(context)!.translate('input_confirm_password_tip') );
      return;
    }
    if (newPwd != confirmPwd) {
      _showToast(context, "两次输入的密码不一致");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 调用重置密码接口（需后端提供，这里假设接口路径）
      Response result = await HttpUtil.put(
        resetPasswordUrl, // 新增：在service_url.dart定义重置密码接口
        data: {
          "memberName": _memberName, // 关键修改：提交存储的会员名
          "email": email, // 原邮箱参数保留
          "password": newPwd, // 关键修改：参数名改为password（匹配需求格式）
          "passwordCheck": confirmPwd // 关键修改：参数名改为passwordCheck（匹配需求格式）
        },
      );

      if (result.data['code'] == 200) {
        // 重置成功：提示+跳转到登录页
        _showToast(context, result.data['msg'] , isSuccess: true);
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const Login()),
              (route) => false,
            );
          });
        }
      } else {
        _showToast(context, result.data['msg']);
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? "网络错误，请检查网络"
          : "重置异常，请重试";
      _showToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 7. 通用提示弹窗（完全复用登录/注册页）
  void _showToast(BuildContext context, String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 8. 通用输入行组件（复用登录/注册页，支持密码隐藏）
  Widget _buildInputRow({
    required String labelText,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    bool readOnly = false,
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
              enabled: !_isLoading,
              readOnly: readOnly,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIcon: suffixIcon,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 9. 带验证码按钮的邮箱输入行（复用注册页布局）
  Widget _buildEmailWithVerifyCodeRow() {
    final loc = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(
            loc.translate('email') ,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading && _canGetVerifyCode, // 倒计时时禁用邮箱输入
              decoration: InputDecoration(
                hintText: loc.translate('input_email_hint') ,
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: _canGetVerifyCode && !_isLoading ? _sendVerifyCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canGetVerifyCode ? const Color.fromARGB(255, 116, 115, 115) : const Color.fromARGB(255, 138, 138, 138),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _verifyCodeText,
                style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 12),
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
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ---------------------- 1. 上半部分（完全复用登录/注册页，样式不变） ----------------------
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('images/bjttb.png'),
                  fit: BoxFit.cover,
                ),
              ),
              padding: EdgeInsets.only(
                top: 50,
                right: _logoRightPadding,
                bottom: 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 返回按钮
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 0, 0, 0), size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
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
                        loc.translate('smart_consumer_start') ,
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

            const SizedBox(height: 40),

            // ---------------------- 2. 表单区域（分两步切换） ----------------------
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.symmetric(
                  horizontal: _inputHorizontalMargin,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 第一步：邮箱 + 验证码 + 下一步（_isFirstStep=true时显示）
                    if (_isFirstStep) ...[
                      // 邮箱+发送验证码
                      _buildEmailWithVerifyCodeRow(),
                      const SizedBox(height: 20),
                      // 验证码输入框
                      _buildInputRow(
                        labelText: loc.translate('verify_code'),
                        controller: _verifyCodeController,
                        hintText: loc.translate('input_verify_code_hint') ,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 30),
                      // 下一步按钮
                      InkWell(
                        onTap: _isLoading ? null : _goToSecondStep,
                        child: Container(
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey[300] : const Color.fromARGB(255, 243, 215, 53),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text(
                                  loc.translate('next_step') ?? "下一步",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                    ] 
                    // 第二步：新密码 + 确认密码 + 确认（_isFirstStep=false时显示）
                    else ...[
                      // 新密码输入框（带隐藏/显示图标）
                      _buildInputRow(
                        labelText: loc.translate('new_password'),
                        controller: _newPwdController,
                        hintText: loc.translate('input_new_password_hint') ,
                        obscureText: _isObscureNewPwd,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscureNewPwd ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _isObscureNewPwd = !_isObscureNewPwd),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 确认密码输入框（带隐藏/显示图标）
                      _buildInputRow(
                        labelText: loc.translate('confirm_password') ,
                        controller: _confirmPwdController,
                        hintText: loc.translate('input_confirm_password_hint'),
                        obscureText: _isObscureConfirmPwd,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscureConfirmPwd ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _isObscureConfirmPwd = !_isObscureConfirmPwd),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 确认按钮
                      InkWell(
                        onTap: _isLoading ? null : _submitNewPassword,
                        child: Container(
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey[300] : const Color.fromARGB(255, 243, 215, 53),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text(
                                  loc.translate('confirm'),
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}