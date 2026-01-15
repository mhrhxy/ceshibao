import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart'; // 导入剪贴板功能
import 'package:dio/dio.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/loginto.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'model/toast_model.dart';

/// 忘记账号页面（分两步：1.邮箱验证 2.显示账号+复制）
class ForgotAccount extends StatefulWidget {
  const ForgotAccount({super.key});

  @override
  State<ForgotAccount> createState() => _ForgotAccountState();
}

class _ForgotAccountState extends State<ForgotAccount> {
  // 1. 输入控制器（仅保留邮箱+验证码，删除密码控制器）
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verifyCodeController = TextEditingController();

  // 2. 状态控制变量（调整：删除密码相关状态，新增复制状态）
  bool _isLoading = false; // 全局加载状态
  bool _canGetVerifyCode = true; // 发送验证码按钮状态
  String _verifyCodeText = ""; // 验证码按钮文本
  bool _isFirstStep = true; // 步骤标记：true=验证页，false=显示账号页
  bool _isFirstInit = true; // 国际化初始化标记
  String? _memberName; // 存储接口返回的用户名
  bool _isCopied = false; // 复制状态：false=未复制，true=已复制

  // 3. 布局参数（复用忘记密码页，保持风格统一）
  final double _labelWidth = 80.w;
  final double _inputHorizontalMargin = 40.w;
  final double _logoRightPadding = 30.w;

  @override
  void initState() {
    super.initState();
    // 测试数据（可选删除）
    _emailController.text = "";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次初始化国际化文本
    if (_isFirstInit) {
      _verifyCodeText = AppLocalizations.of(context)!.translate('send_code');
      _isFirstInit = false;
    }
  }

  @override
  void dispose() {
    // 释放控制器资源（仅保留邮箱+验证码控制器）
    _emailController.dispose();
    _verifyCodeController.dispose();
    super.dispose();
  }

  /// 4. 核心逻辑1：发送验证码（完全复用忘记密码页逻辑）
  Future<void> _sendVerifyCode() async {
    final email = _emailController.text.trim();
    // 邮箱校验
    if (email.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_email_tip'));
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('email_format_error'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 调用发送验证码接口（忘记账号场景type，需与后端确认，这里复用type=3）
      Response result = await HttpUtil.post(
        apisendemail,
        queryParameters: {"email": email, "type": "4"},
      );

      if (result.data['code'] == 200) {
        ToastUtil.showCustomToast(context, result.data['msg'] ?? "验证码已发送");
        setState(() {
          _canGetVerifyCode = false;
          _verifyCodeText = AppLocalizations.of(context)!.translate('countdown_60s');
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
              _verifyCodeText = "${AppLocalizations.of(context)!.translate('countdown_second')}"
                  .replaceAll("%s", countdown.toString());
            });
          }
        });
      } else {
        ToastUtil.showCustomToast(context, result.data['msg']);
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? AppLocalizations.of(context)!.translate('network_error') ?? "网络错误"
          : "发送异常，请重试";
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 5. 核心逻辑2：第一步「确认」- 验证邮箱+验证码（获取用户名）
  Future<void> _verifyEmailAndCode() async {
    final email = _emailController.text.trim();
    final code = _verifyCodeController.text.trim();
    // 表单校验
    if (email.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_email_tip'));
      return;
    }
    if (code.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_verify_code_tip'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 调用验证接口（获取用户名，需与后端确认接口路径，这里复用verifyForgotCodeUrl）
      Response result = await HttpUtil.post(
        verifyForgotCodeUrl,
        data: {
          "email": email,
          "type": '4', // 需与后端确认忘记账号场景的type值
          "code": code
        },
      );

      if (result.data['code'] == 200) {
        // 验证成功：存储用户名+切换到第二步
        setState(() {
          _isFirstStep = false;
          _memberName = result.data['msg']; // 接口返回的用户名
          _verifyCodeController.clear(); // 清空验证码
        });
      } else {
        ToastUtil.showCustomToast(context, result.data['msg']);
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? "网络错误，请检查网络"
          : "验证异常，请重试";
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 6. 核心逻辑3：复制用户名到剪贴板
  Future<void> _copyMemberName() async {
    if (_memberName == null || _memberName!.isEmpty) return;

    // 复制到剪贴板
    await Clipboard.setData(ClipboardData(text: _memberName!));
    // 切换复制状态（2秒后恢复）
    setState(() => _isCopied = true);
    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
    ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('copy_success') ?? "复制成功");
  }

  /// 7. 核心逻辑4：第二步「确认」- 返回登录页
  void _backToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Loginto()),
      (route) => false,
    );
  }

  /// 8. 通用提示弹窗（复用忘记密码页）
  // 使用ToastUtil代替本地_showToast方法

  /// 9. 通用输入行组件（复用忘记密码页）
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
            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: SizedBox(
            height: 50.h,
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              enabled: !_isLoading,
              readOnly: readOnly,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
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

  /// 10. 带验证码按钮的邮箱输入行（复用忘记密码页）
  Widget _buildEmailWithVerifyCodeRow() {
    final loc = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(
            loc.translate('email'),
            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50.h,
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading && _canGetVerifyCode,
              decoration: InputDecoration(
                hintText: loc.translate('input_email_hint'),
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        SizedBox(
          height: 30.h,
          child: ElevatedButton(
            onPressed: _canGetVerifyCode && !_isLoading ? _sendVerifyCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canGetVerifyCode ? const Color.fromARGB(255, 116, 115, 115) : const Color.fromARGB(255, 138, 138, 138),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            ),
            child: Text(
              _verifyCodeText,
              style: TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 12.sp),
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
                        icon: Icon(Icons.arrow_back, color: Color.fromARGB(255, 0, 0, 0), size: 24.w),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Logo和标语（复用）
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'images/logo.png',
                        width: 300.w,
                        height: 100.h,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        loc.translate('smart_consumer_start'),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 40.h),

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
                    // 第一步：邮箱 + 验证码 + 确认按钮
                    if (_isFirstStep) ...[
                      _buildEmailWithVerifyCodeRow(),
                      SizedBox(height: 20.h),
                      // 验证码输入框
                      _buildInputRow(
                        labelText: loc.translate('verify_code'),
                        controller: _verifyCodeController,
                        hintText: loc.translate('input_verify_code_hint'),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 30.h),
                      // 确认按钮（文字从"下一步"改为"确认"）
                      InkWell(
                        onTap: _isLoading ? null : _verifyEmailAndCode,
                        child: Container(
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: 50.h,
                          decoration: BoxDecoration(
                            color: _isLoading ? Colors.grey[300] : const Color.fromARGB(255, 243, 215, 53),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text(
                                  loc.translate('confirm') ?? "确认", // 按钮文字改为"确认"
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                    ]
                    // 第二步：显示用户名 + 复制按钮 + 确认返回登录页
                    else ...[
                      // 用户名显示区域（带复制功能）
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 用户名文本
                            Expanded(
                              child: Text(
                                "${loc.translate('your_account') ?? '您的账号：'} ${_memberName ?? ''}",
                                style: TextStyle(fontSize: 16.sp, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            // 复制按钮
                            TextButton(
                              onPressed: _copyMemberName,
                              style: TextButton.styleFrom(
                                foregroundColor: _isCopied ? Colors.green : const Color.fromARGB(255, 116, 115, 115),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                              child: Text(
                                _isCopied 
                                    ? loc.translate('copied') ?? '已复制' 
                                    : loc.translate('copy') ?? '复制',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 50.h),
                      // 确认返回登录页按钮
                      InkWell(
                        onTap: _isLoading ? null : _backToLogin,
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
                                  loc.translate('confirm') ?? "确认",
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