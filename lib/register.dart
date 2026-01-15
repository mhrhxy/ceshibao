import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'loginto.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'model/toast_model.dart';

/// 注册页面（完整功能：邮箱验证码接口 + 表单验证 + 倒计时 + 国际化）
class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  // 输入控制器（完全保留原有逻辑）
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _verifyCodeController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // UI状态控制（原有字段 + 网络请求实例）
  bool _isRegisterLoading = false;
  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;
  bool _canGetVerifyCode = true;
  String _verifyCodeText = "";
  bool _isFirstInit = true;

  // 布局参数（增加标签宽度避免换行）
  final double _labelWidth = 80.w;
  final double _inputHorizontalMargin = 40.w;
  final double _logoRightPadding = 30.w;

  @override
  void initState() {
    super.initState();
    // 测试数据初始化（原有逻辑）
    _accountController.text = "";
    _passwordController.text = "";
    _confirmPasswordController.text = "";
    _usernameController.text = "";
    _emailController.text = "";
    _phoneController.text = "";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次初始化国际化文本（避免initState依赖错误）
    if (_isFirstInit) {
      _verifyCodeText =
          AppLocalizations.of(context)!.translate('send_code') ?? "发送验证码";
      _isFirstInit = false;
    }
  }

  @override
  void dispose() {
    // 释放所有控制器（防止内存泄漏）
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verifyCodeController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// 核心：调用 email/send?email=xxx 接口 + 原有倒计时逻辑
  /// 验证码接口调用（与登录页_submitLoginData逻辑完全对齐）
  Future<void> _mockGetVerifyCode() async {
    // 1. 输入校验（同登录页的账号密码校验逻辑）
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_email_tip'),
      );
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('email_format_error'),
      );
      return;
    }

    // 2. 显示加载状态（同登录页的_isLoginLoading控制逻辑）
    setState(() => _isRegisterLoading = true);

    try {
      // 使用service_url.dart中定义的常量，确保使用正确的baseUrl
      Response result = await HttpUtil.post(apisendemail, queryParameters: {"email": email, "type": "2"});

      // 4. 接口结果处理（同登录页的LoginModel解析逻辑，简化为直接处理返回数据）
      if (result.data['code'] == 200) {
        // 成功：执行倒计时+提示（对应登录页的"登录成功跳转"逻辑）
        setState(() {
          _canGetVerifyCode = false;
          _verifyCodeText = AppLocalizations.of(
            context,
          )!.translate('countdown_60s');
        });
        ToastUtil.showCustomToast(
          context,
          AppLocalizations.of(context)!.translate('verify_code_sent'),
        );

        // 原有倒计时逻辑（保留，不改动）
        int countdown = 60;
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (countdown == 0) {
            if (mounted) {
              setState(() {
                _verifyCodeText = AppLocalizations.of(
                  context,
                )!.translate('send_code');
                _canGetVerifyCode = true;
              });
            }
            timer.cancel();
            return;
          }
          if (mounted) {
            setState(() {
              countdown--;
              _verifyCodeText = AppLocalizations.of(context)!
                  .translate('countdown_second')
                  .replaceAll("%s", countdown.toString());
            });
          }
        });
      } else {
        // 失败：显示接口返回的错误信息（同登录页的"登录失败提示"逻辑）
        ToastUtil.showCustomToast(
          context,
          result.data['msg'] ??
              AppLocalizations.of(context)!.translate('send_code_failed'),
        );
      }
    } catch (e) {
      // 5. 异常处理（与登录页完全一致：区分DioError+国际化文本）
      String errorMsg =
          e is DioError
              ? AppLocalizations.of(context)!.translate('network_error')
              : AppLocalizations.of(context)!.translate('send_code_exception');
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      // 6. 隐藏加载状态（同登录页的"无论成败都关闭加载"逻辑）
      if (mounted) {
        setState(() => _isRegisterLoading = false);
      }
    }
  }

  /// 注册接口核心逻辑（参数校验+Http调用+结果处理）
  Future<void> _submitRegister() async {
    // 1. 读取输入参数并去空格
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final code = _verifyCodeController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final birthday =
        _birthdayController.text
            .trim(); // 注意：需确认格式是否匹配接口要求（接口是"01-01"，当前是"年-月-日"）
    final password = _passwordController.text.trim();
    final passwordCheck = _confirmPasswordController.text.trim();

    // 2. 基础参数校验（避免无效请求，与登录页校验逻辑一致）
    if (username.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_username_hint'),
      );
      return;
    }
    if (email.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_email_tip'),
      );
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('email_format_error'),
      );
      return;
    }
    if (code.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_verify_code_hint'),
      );
      return;
    }
    if (phoneNumber.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_phone_hint'),
      );
      return;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phoneNumber)) {
      // 手机号正则校验（可选，根据需求调整）
      ToastUtil.showCustomToast(context, "请输入正确的手机号");
      return;
    }
    if (birthday.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('select_birthday_hint'),
      );
      return;
    }
    if (password.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_password_tip'),
      );
      return;
    }
    if (passwordCheck.isEmpty) {
      ToastUtil.showCustomToast(
        context,
        AppLocalizations.of(context)!.translate('input_confirm_password_tip'),
      );
      return;
    }
    if (password != passwordCheck) {
      // 密码与确认密码一致性校验
      ToastUtil.showCustomToast(context, "两次输入的密码不一致");
      return;
    }

    // 3. 显示注册加载状态（复用原有_isRegisterLoading，与登录页一致）
    setState(() => _isRegisterLoading = true);

    try {
      // 4. 组装注册参数（完全匹配接口要求的key）
      Map<String, dynamic> registerParams = {
        "username": username,
        "email": email,
        "code": code,
        "phoneNumber": phoneNumber,
        "birthday":
            birthday, // 注意：若接口需要"月-日"格式（如"01-01"），需调整：birthday.split('-').sublist(1).join('-')
        "password": password,
        "passwordCheck": passwordCheck,
      };

      // 5. 调用注册接口（与登录/验证码接口风格一致：HttpUtil.post + data传参）
      // 需在 service_url.dart 中新增注册接口地址：const String registerUrl = "xxx/register";（替换为你的实际接口路径）
      Response result = await HttpUtil.post(
        apiregister, // 你的注册接口地址（从service_url.dart获取）
        data: registerParams, // 参数放data中（适配你的HttpUtil）
      );

      // 6. 处理接口返回（与登录/验证码一致：判断code==200）
      if (result.data['code'] == 200) {
        // 注册成功：提示+跳转到登录页（清除注册页栈，避免返回）
        ToastUtil.showCustomToast(
          context,
          result.data['msg'],
        );
        // 延迟跳转（让用户看到成功提示）
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const Loginto()), // 跳转到登录页
              (route) => false, // 清除当前页面栈
            );
          });
        }
      } else {
        // 注册失败：显示接口返回的错误信息
        ToastUtil.showCustomToast(
          context,
          result.data['msg'] ??
              AppLocalizations.of(context)!.translate('register_failed'),
        );
      }
    } catch (e) {
      // 7. 异常处理（与登录/验证码完全一致）
      String errorMsg =
          e is DioError
              ? AppLocalizations.of(context)!.translate('network_error')
              : AppLocalizations.of(context)!.translate('register_exception');
      ToastUtil.showCustomToast(context, errorMsg);
    } finally {
      // 8. 隐藏加载状态（无论成败都执行，与登录页一致）
      if (mounted) {
        setState(() => _isRegisterLoading = false);
      }
    }
  }

  /// 选择生日（自定义CupertinoPicker实现纯数字显示）
  void _selectBirthday() {
    DateTime now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    int selectedDay = now.day;
    
    // 显示底部弹出的日期选择器
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext builderContext) {
        // 生成年份列表
        List<int> years = List.generate(now.year - 1899, (index) => 1900 + index);
        // 生成月份列表（1-12）
        List<int> months = List.generate(12, (index) => index + 1);
        
        // 生成天数列表（根据月份动态调整）
        int getDaysInMonth(int year, int month) {
          return DateTime(year, month + 1, 0).day;
        }
        List<int> days = List.generate(getDaysInMonth(selectedYear, selectedMonth), (index) => index + 1);
        
        return Container(
          height: 300.h,
          color: Colors.white,
          child: Column(
            children: [
              // 顶部操作栏
              Container(
                height: 50.h,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1.w,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 取消按钮
                    CupertinoButton(
                      onPressed: () => Navigator.of(builderContext).pop(),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        AppLocalizations.of(context)!.translate('cancel'),
                        style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                      ),
                    ),
                    // 确认按钮
                    CupertinoButton(
                      onPressed: () {
                        Navigator.of(builderContext).pop();
                        if (mounted) {
                          setState(() {
                            _birthdayController.text =
                                "${selectedYear}-${selectedMonth.toString().padLeft(2, '0')}-${selectedDay.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        AppLocalizations.of(context)!.translate('confirm'),
                        style: TextStyle(color: Colors.blue, fontSize: 16.sp),
                      ),
                    ),
                  ],
                ),
              ),
              // 自定义日期选择器（三个独立的CupertinoPicker）
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 年份选择器
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedYear - 1900),
                        itemExtent: 36.h,
                        backgroundColor: Colors.white,
                        onSelectedItemChanged: (int index) {
                          selectedYear = years[index];
                        },
                        children: years.map((year) => Center(child: Text('$year', style: TextStyle(fontSize: 16.sp, color: Colors.black)))).toList(),
                      ),
                    ),
                    // 月份选择器
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedMonth - 1),
                        itemExtent: 36.h,
                        backgroundColor: Colors.white,
                        onSelectedItemChanged: (int index) {
                          selectedMonth = months[index];
                        },
                        children: months.map((month) => Center(child: Text('$month', style: TextStyle(fontSize: 16.sp, color: Colors.black)))).toList(),
                      ),
                    ),
                    // 天数选择器
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedDay - 1),
                        itemExtent: 36.h,
                        backgroundColor: Colors.white,
                        onSelectedItemChanged: (int index) {
                          selectedDay = days[index];
                        },
                        children: days.map((day) => Center(child: Text('$day', style: TextStyle(fontSize: 16.sp, color: Colors.black)))).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示提示弹窗（原有逻辑完全保留）
  // 使用ToastUtil代替本地_showToast方法

  /// 通用输入行组件（原有UI完全保留）
  Widget _buildInputRow({
    required String labelText,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    VoidCallback? onTap,
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
              enabled: !_isRegisterLoading,
              readOnly: readOnly,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
                suffixIcon: suffixIcon,
              ),
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }

  /// 带验证码按钮的邮箱输入行（原有UI完全保留）
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
              enabled: !_isRegisterLoading,
              decoration: InputDecoration(
                hintText: loc.translate('input_email_hint'),
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 12.h,
                ),
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
              onPressed:
                  _canGetVerifyCode && !_isRegisterLoading
                      ? _mockGetVerifyCode
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canGetVerifyCode
                        ? const Color.fromARGB(255, 255, 255, 255)
                        : const Color.fromARGB(255, 0, 0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.r),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _verifyCodeText,
                style: TextStyle(
                  color: const Color.fromARGB(255, 0, 0, 0),
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 验证码输入行（原有UI完全保留）
  Widget _buildVerifyCodeRow() {
    final loc = AppLocalizations.of(context)!;
    return _buildInputRow(
      labelText: loc.translate('verify_code'),
      controller: _verifyCodeController,
      hintText: loc.translate('input_verify_code_hint'),
      keyboardType: TextInputType.number,
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
            // 顶部背景区域
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('images/bjttb.png'),
                  fit: BoxFit.cover,
                ),
              ),
              padding: EdgeInsets.only(
                top: 50.h,
                right: _logoRightPadding,
                bottom: 30.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                        loc.translate('smart_consumer_start'),
                        style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // 可滚动表单区域（原有UI完全保留）
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: _inputHorizontalMargin,
                  vertical: 10.h,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 用户名输入行
                    _buildInputRow(
                      labelText: loc.translate('username'),
                      controller: _usernameController,
                      hintText: loc.translate('input_username_hint'),
                    ),
                    SizedBox(height: 20.h),

                    // 邮箱+验证码按钮
                    _buildEmailWithVerifyCodeRow(),
                    SizedBox(height: 20.h),

                    // 验证码输入行
                    _buildVerifyCodeRow(),
                    SizedBox(height: 20.h),

                    // 生日选择行
                    _buildInputRow(
                      labelText: loc.translate('birthday'),
                      controller: _birthdayController,
                      hintText: loc.translate('select_birthday_hint'),
                      onTap: _selectBirthday,
                      readOnly: true,
                    ),
                    SizedBox(height: 20.h),

                    // 手机号输入行
                    _buildInputRow(
                      labelText: loc.translate('phone'),
                      controller: _phoneController,
                      hintText: loc.translate('input_phone_hint'),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 20.h),

                    // 密码输入行
                    _buildInputRow(
                      labelText: loc.translate('password'),
                      controller: _passwordController,
                      hintText: loc.translate('input_password_hint'),
                      obscureText: _isObscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                          size: 20.r,
                        ),
                        onPressed:
                            () => setState(
                              () => _isObscurePassword = !_isObscurePassword,
                            ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // 确认密码输入行（补全之前可能截断的部分）
                    _buildInputRow(
                      labelText: loc.translate('confirm_password'),
                      controller: _confirmPasswordController,
                      hintText: loc.translate('input_confirm_password_hint'),
                      obscureText: _isObscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                          size: 20.r,
                        ),
                        onPressed:
                            () => setState(
                              () =>
                                  _isObscureConfirmPassword =
                                      !_isObscureConfirmPassword,
                            ),
                      ),
                    ),
                    SizedBox(height: 30.h),

                    // 注册按钮（完整保留原有样式）
                    // 注册按钮（修改onTap为_submitRegister）
                    InkWell(
                      onTap:
                          _isRegisterLoading ? null : _submitRegister, // 绑定注册逻辑
                      child: Container(
                        alignment: Alignment.center,
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          color:
                              _isRegisterLoading
                                  ? Colors.grey[300]
                                  : const Color.fromARGB(255, 243, 215, 53),
                          borderRadius: BorderRadius.circular(25.r),
                        ),
                        child:
                            _isRegisterLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                                : Text(
                                  loc.translate('register'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                      ),
                    ),
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
