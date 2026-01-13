import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'loginto.dart';
import 'dingbudaohang.dart';
import './utils/http_util.dart';
import './config/service_url.dart';

class ExitMemberPage extends StatefulWidget {
  const ExitMemberPage({super.key});

  @override
  State<ExitMemberPage> createState() => _ExitMemberPageState();
}

class _ExitMemberPageState extends State<ExitMemberPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 退出会员确认
  Future<void> _submitExitMember() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();

    // 前端校验 - 确保先执行验证再显示确认框
    if (account.isEmpty) {
      _showValidationError(AppLocalizations.of(context)?.translate('account_empty') ?? '账号不能为空');
      return;
    }

    if (password.isEmpty) {
      _showValidationError(AppLocalizations.of(context)?.translate('password_empty') ?? '密码不能为空');
      return;
    }

    // 只有验证通过后，才显示确认退出提示框
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)?.translate('exit_member_confirm_tip') ?? '退出会员后积分与优惠券将会清空，确认退出会员？',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18.sp), // 增大文字大小
                ),
                SizedBox(height: 24.h),
                // 按钮容器：左右排列
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 确认按钮
                    Expanded(
                      child: SizedBox(
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // 关闭确认提示框
                            // 执行真正的退出会员操作
                            await _processExitMember();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // 圆角设计
                            ),
                            textStyle:  TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确认'),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w), // 按钮间距
                    // 取消按钮
                    Expanded(
                      child: SizedBox(
                        height: 50.h,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // 关闭确认提示框
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // 圆角设计
                            ),
                            textStyle:  TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: Text(AppLocalizations.of(context)?.translate('cancel') ?? '取消'),
                        ),
                      ),
                    )
                  ]
                ),
                SizedBox(height: 20.h),
              ],
            ),
            actions: [], // 清空默认actions
          ),
      );
    }
  }

  // 显示验证错误提示
  void _showValidationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2), // 增加提示显示时间
        ),
      );
    }
  }

  // 处理真正的退出会员操作
  Future<void> _processExitMember() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 获取输入的账号和密码
      String username = _accountController.text.trim();
      String password = _passwordController.text.trim();

      // 调用退出会员接口 - DELETE请求
      // 注意：服务器端参数名拼写错误，使用'ursername'而不是'username'
      Map<String, dynamic> queryParams = {
        'ursername': username,
        'password': password,
      };
      Response response = await HttpUtil.del(exitMemberUrl, queryParameters: queryParams);

      // 处理响应结果
      if (response.statusCode == 200) {
        // 检查业务状态码
        dynamic responseData = response.data;
        if (responseData is Map && responseData.containsKey('code')) {
          int code = responseData['code'];
          if (code == 200) {
            // 业务处理成功
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(AppLocalizations.of(context)?.translate('exit_member_success') ?? '退出会员成功！'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // 关闭提示框
                        _clearLoginState(); // 清除登录状态
                      },
                      child: Center(child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确定')), // 显式设置文字居中
                    ),
                  ],
                ),
              );
            }
          } else {
            // 业务处理失败
            String errorMsg = responseData['msg'] ?? responseData['message'] ?? '退出会员失败';
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(errorMsg),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // 关闭提示框
                      },
                      child: Center(child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确定')), // 显式设置文字居中
                    ),
                  ],
                ),
              );
            }
          }
        } else {
          // 响应格式不符合预期，视为失败
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(AppLocalizations.of(context)?.translate('exit_member_format_error') ?? '退出会员失败，响应格式错误'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // 关闭提示框
                    },
                    child: Center(child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确定')), // 显式设置文字居中
                  ),
                ],
              ),
            );
          }
        }
      } else {
        // HTTP请求失败
        String errorMsg = response.data['msg'] ?? response.data['message'] ?? '退出会员失败';
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(errorMsg),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // 关闭提示框
                  },
                  child: Center(child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确定')), // 显式设置文字居中
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // 处理异常情况
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Text('${AppLocalizations.of(context)?.translate('operation_failed') ?? '操作失败'}：${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 关闭提示框
                },
                child: Center(child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确定')), // 显式设置文字居中
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 输入项组件（左右结构）
  Widget _buildInputItem({
    required String title,
    required String hintText,
    required TextEditingController controller,
    required bool isPassword,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              title,
              style:  TextStyle(
                color: Colors.black87,
                fontSize: 16.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFFEEEEEE)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 清除登录状态
  Future<void> _clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('member_info');
      await prefs.setBool('isLogin', false);

      // 跳转到登录页
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const Loginto(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // 处理清除失败的情况
      print('清除登录状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 返回栏 + 标题
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)?.translate('exit_member') ?? '退出会员页',
                      style:  TextStyle(
                        color: Colors.black87,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 48.w),
              ],
            ),
          ),

          // 表单区域
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ListView(
                children: [
                  // 账号输入框
                  _buildInputItem(
                    title: AppLocalizations.of(context)?.translate('account') ?? '账号',
                    hintText: AppLocalizations.of(context)?.translate('input_account_tip') ?? '请输入账号',
                    controller: _accountController,
                    isPassword: false,
                  ),

                  // 密码输入框
                  _buildInputItem(
                    title: AppLocalizations.of(context)?.translate('password') ?? '密码',
                    hintText: AppLocalizations.of(context)?.translate('input_password_tip') ?? '请输入密码',
                    controller: _passwordController,
                    isPassword: true,
                  ),

                  // 确认按钮
                  Container(
                    margin: const EdgeInsets.only(top: 60),
                    child: Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitExitMember,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Center(
                                child: Text(
                                  AppLocalizations.of(context)?.translate('confirm') ?? '确认',
                                  style:  TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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
    );
  }
}