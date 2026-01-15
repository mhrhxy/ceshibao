import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import 'model/toast_model.dart';

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
  final double _labelWidth = 60.w;
  final double _inputHorizontalMargin = 40.w;
  final double _logoRightPadding = 30.w;

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
      // 设置请求头（携带登录成功的token）
      HttpUtil.dio.options.headers['Authorization'] = 'Bearer $token';
      
      // 调用最大订单限额接口
      Response result = await HttpUtil.get(maxOrderPurchaseLimitUrl);
      
      if (result.data['code'] == 200) {
        // 保存最大订单限额到本地
        String maxLimit = result.data['msg'] ?? '0';
        await SharedPreferencesUtil.saveString('maxOrderLimit', maxLimit);
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
          ToastUtil.showCustomToast(
            context, 
            AppLocalizations.of(context)!.translate('get_user_info_failed')
          );
        }
      }
    } catch (e) {
      // 异常处理（网络错误等，不阻断登录）
      if (mounted) {
        ToastUtil.showCustomToast(
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
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_account_tip'));
      return;
    }
    if (password.isEmpty) {
      ToastUtil.showCustomToast(context, AppLocalizations.of(context)!.translate('input_password_tip'));
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
          ToastUtil.showCustomToast(
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
        ToastUtil.showCustomToast(context, errorMsg);
      }
    } finally {
      // 7. 隐藏加载状态
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }

  // 使用ToastUtil代替本地_showToast方法

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
            style: TextStyle(fontSize: 16.sp, color: Colors.black87),
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
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
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
          toolbarHeight: 60.h,
          leading: Padding(
            padding: EdgeInsets.only(left: 4.w, top: 4.h),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.r),
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
                top: 50.h,
                bottom: 30.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 返回按钮已移至AppBar
                  SizedBox(height: 20.h),
                  // Logo和标语
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
                        '“${AppLocalizations.of(context).translate('smart_consumer_start')}',
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

            SizedBox(height: 20.h),

            // 登录表单区域
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: _inputHorizontalMargin,
                vertical: 10.h,
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
                  SizedBox(height: 20.h),

                  // 密码输入行
                  _buildInputRow(
                    labelText: loc.translate('password'),
                    controller: _passwordController,
                    hintText: loc.translate('input_password_hint'),
                    obscureText: true,
                    enabled: !_isLoginLoading,
                  ),

                  SizedBox(height: 20.h),

                  // 辅助按钮区
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 16.0.w,
                      runSpacing: 4.0.h,
                      children: [
                        TextButton(
                          onPressed: _isLoginLoading ? null : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const Register()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                          ),
                          child: Text(
                            loc.translate('register'),
                            style: TextStyle(color: Colors.black87, fontSize: 14.sp),
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
                            style: TextStyle(color: Colors.black87, fontSize: 14.sp),
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
                            style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30.h),

                  // 登录按钮
                  InkWell(
                    onTap: _isLoginLoading ? null : _submitLoginData,
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: _isLoginLoading ? Colors.grey[300] : const Color.fromARGB(255, 243, 215, 53),
                        borderRadius: BorderRadius.circular(25.r),
                      ),
                      child: _isLoginLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Text(
                              loc.translate('login'),
                              style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}