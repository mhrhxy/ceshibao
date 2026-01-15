import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/login.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'model/toast_model.dart';

/// 忘记密码页面（带密码格式校验）
class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  // 输入控制器
  final TextEditingController _memberNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verifyCodeController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();

  // 状态控制变量
  bool _isLoading = false;
  bool _canGetVerifyCode = true;
  String _verifyCodeText = "";
  bool _isFirstStep = true;
  bool _isObscureNewPwd = true;
  bool _isObscureConfirmPwd = true;
  bool _isFirstInit = true;
  String? _memberName;
  // 新增：密码格式错误提示
  String? _pwdErrorText;

  // 布局参数
  final double _labelWidth = 80.w;
  final double _inputHorizontalMargin = 40.w;
  final double _logoRightPadding = 30.w;

  // 新增：密码校验正则（仅允许小写字母、数字、特殊符号）
  static final RegExp _passwordRegExp = RegExp(
    r'^[a-z0-9!@#$%^&*(),.?":{}|<>]+$',
  );

  @override
  void initState() {
    super.initState();
    _memberNameController.text = "";
    _emailController.text = "";
    
    // 新增：实时监听密码输入，更新错误提示
    _newPwdController.addListener(() {
      final pwd = _newPwdController.text.trim();
      setState(() {
        _pwdErrorText = pwd.isNotEmpty && !_passwordRegExp.hasMatch(pwd)
            ? AppLocalizations.of(context)!.translate('pwd_format_error')
            : null;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstInit) {
      _verifyCodeText = AppLocalizations.of(context)!.translate('send_code') ;
      _isFirstInit = false;
    }
  }

  @override
  void dispose() {
    _memberNameController.dispose();
    _emailController.dispose();
    _verifyCodeController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  /// 发送验证码（不变）
  Future<void> _sendVerifyCode() async {
    // ... 原有逻辑保持不变 ...
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_email_tip'));
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('email_format_error')  );
      return;
    }

    setState(() => _isLoading = true);
    try {
      Response result = await HttpUtil.post(
        apisendemail,
        queryParameters: {"email": email, "type": "3"},
      );

      if (result.data['code'] == 200) {
        ToastUtil.showCustomToast(context, result.data['msg'] ?? AppLocalizations.of(context)!.translate('verify_code_sent'));
        setState(() {
          _canGetVerifyCode = false;
          _verifyCodeText = AppLocalizations.of(context)!.translate('countdown_60s') ;
        });

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
        ToastUtil.showCustomToast(context, result.data['msg'] );
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? AppLocalizations.of(context)!.translate('network_error')
          : AppLocalizations.of(context)!.translate('send_exception_retry');
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 第一步「下一步」（不变）
  Future<void> _goToSecondStep() async {
    // ... 原有逻辑保持不变 ...
    final memberName = _memberNameController.text.trim();
    final email = _emailController.text.trim();
    final code = _verifyCodeController.text.trim();

    if (memberName.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_account_tip'));
      return;
    }
    if (email.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_email_tip'));
      return;
    }
    if (code.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_verify_code_tip') );
      return;
    }

    setState(() => _isLoading = true);
    try {
      Response result = await HttpUtil.post(
        verifyForgotCodeUrl,
        data: {
          "memberName": memberName,
          "email": email,
          "type": '3',
          "code": code
        },
      );

      if (result.data['code'] == 200) {
        setState(() {
          _isFirstStep = false;
          _memberName = memberName;
          _verifyCodeController.clear();
        });
      } else {
        ToastUtil.showCustomToast(context, result.data['msg']);
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? AppLocalizations.of(context)!.translate('network_error_check')
          : AppLocalizations.of(context)!.translate('verify_exception_retry');
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 第二步「确认」- 新增密码格式校验
  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final newPwd = _newPwdController.text.trim();
    final confirmPwd = _confirmPwdController.text.trim();

    // 1. 密码非空校验
    if (newPwd.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_password_tip') );
      return;
    }
    // 2. 密码长度校验
    if (newPwd.length < 6) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('new_pwd_min_length'));
      return;
    }
    // 3. 新增：密码格式校验（小写、数字、特殊符号）
    if (!_passwordRegExp.hasMatch(newPwd)) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('pwd_format_error'));
      return;
    }
    // 4. 确认密码校验
    if (confirmPwd.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_confirm_password_tip') );
      return;
    }
    // 5. 两次密码一致性校验
    if (newPwd != confirmPwd) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('pwd_not_match'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      Response result = await HttpUtil.put(
        resetPasswordUrl,
        data: {
          "memberName": _memberName,
          "email": email,
          "password": newPwd,
          "passwordCheck": confirmPwd
        },
      );

      if (result.data['code'] == 200) {
        ToastUtil.showCustomToast(context, result.data['msg'] );
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const Login()),
              (route) => false,
            );
          });
        }
      } else {
        ToastUtil.showCustomToast(context, result.data['msg']);
      }
    } catch (e) {
      String errorMsg = e is DioError
          ? AppLocalizations.of(context)!.translate('network_error_check')
          : AppLocalizations.of(context)!.translate('reset_exception_retry');
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 提示弹窗（不变）
  // 使用ToastUtil代替本地_showToast方法

  /// 通用输入行组件 - 新增密码错误提示
  Widget _buildInputRow({
    required String labelText,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    bool readOnly = false,
    // 新增：错误提示文字
    String? errorText,
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
            height: errorText != null ? 70 : 50, // 有错误时增加高度
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  enabled: !_isLoading,
                  readOnly: readOnly,
                  decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: errorText != null ? Colors.red : Colors.grey, // 错误时显示红色边框
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                suffixIcon: suffixIcon,
              ),
                ),
                // 新增：显示错误提示
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      errorText,
                      style: TextStyle(color: Colors.red, fontSize: 12.sp),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 带验证码按钮的邮箱输入行（不变）
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
                hintText: loc.translate('input_email_hint') ,
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 30.h,
            child: ElevatedButton(
              onPressed: _canGetVerifyCode && !_isLoading ? _sendVerifyCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canGetVerifyCode ? const Color.fromARGB(255, 116, 115, 115) : const Color.fromARGB(255, 138, 138, 138),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _verifyCodeText,
                style: TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 12.sp),
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
            // 上半部分（不变）
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
                        loc.translate('smart_consumer_start') ,
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

            // 表单区域
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
                    // 第一步：账号 + 邮箱 + 验证码 + 下一步
                    if (_isFirstStep) ...[
                      _buildInputRow(
                        labelText:  loc.translate('account'),
                        controller: _memberNameController,
                        hintText: loc.translate('input_account_hints'),
                      ),
                      SizedBox(height: 20.h),
                      _buildEmailWithVerifyCodeRow(),
                      SizedBox(height: 20.h),
                      _buildInputRow(
                        labelText: loc.translate('verify_code'),
                        controller: _verifyCodeController,
                        hintText: loc.translate('input_verify_code_hint') ,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 30.h),
                      InkWell(
                        onTap: _isLoading ? null : _goToSecondStep,
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
                                  loc.translate('next_step') ?? "下一步",
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500),
                                ),
                        ),
                      ),
                    ] 
                    // 第二步：新密码（带格式校验） + 确认密码 + 确认
                    else ...[
                      // 新密码输入框（带实时错误提示）
                      _buildInputRow(
                        labelText: loc.translate('new_password'),
                        controller: _newPwdController,
                        hintText: loc.translate('input_new_password_hint') ?? "请输入新密码（小写字母、数字、特殊符号）",
                        obscureText: _isObscureNewPwd,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscureNewPwd ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _isObscureNewPwd = !_isObscureNewPwd),
                        ),
                        errorText: _pwdErrorText, // 显示密码格式错误
                      ),
                      SizedBox(height: 20.h),
                      // 确认密码输入框
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
                      SizedBox(height: 30.h),
                      InkWell(
                        onTap: _isLoading ? null : _submitNewPassword,
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
                                  loc.translate('confirm'),
                                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500),
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
