import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'dingbudaohang.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // 新增：用于解析本地JSON数据
import './config/service_url.dart';
import './utils/http_util.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({super.key});

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final TextEditingController _oldPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();
  bool _isLoading = false;
  bool _isInfoLoading = true; // 本地数据加载状态
  int? _memberId; // 从本地获取的memberId

  @override
  void initState() {
    super.initState();
    // 改为从本地读取用户信息（获取memberId）
    _loadLocalMemberInfo();
  }

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  // 从本地存储读取用户信息（获取memberId）
  Future<void> _loadLocalMemberInfo() async {
    try {
      // 1. 获取本地存储的用户信息JSON字符串（登录时已保存，键为'member_info'）
      final prefs = await SharedPreferences.getInstance();
      final memberInfoJson = prefs.getString('member_info');

      if (memberInfoJson == null || memberInfoJson.isEmpty) {
        // 本地无数据：提示需要登录
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.translate('please_login') ?? '请先登录',
              ),
            ),
          );
        }
        setState(() => _isInfoLoading = false);
        return;
      }

      // 2. 解析JSON获取memberId
      final Map<String, dynamic> memberInfoData = json.decode(memberInfoJson);
      setState(() {
        _memberId = memberInfoData['memberId'] ?? 0; // 提取memberId
        _isInfoLoading = false;
      });

      // 检查解析结果
      if (_memberId == 0) {
        throw Exception('memberId解析失败');
      }
    } catch (e) {
      setState(() => _isInfoLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.translate('load_failed') ?? '获取信息失败'}：${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  // 提交修改密码请求（使用本地获取的memberId）
  Future<void> _submitChangePassword() async {
    // 检查本地是否获取到memberId
    if (_memberId == null || _memberId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('load_failed') ?? '用户信息获取失败，请重试',
          ),
        ),
      );
      return;
    }

    final oldPwd = _oldPwdController.text.trim();
    final newPwd = _newPwdController.text.trim();
    final confirmPwd = _confirmPwdController.text.trim();

    // 前端校验（保持不变）
    if (oldPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('old_pwd_empty') ?? '原密码不能为空',
          ),
        ),
      );
      return;
    }
    if (newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('new_pwd_empty') ?? '新密码不能为空',
          ),
        ),
      );
      return;
    }
    if (newPwd != confirmPwd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('pwd_not_match') ?? '两次密码不一致',
          ),
        ),
      );
      return;
    }

    try {
      // 获取Token（保持不变）
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('please_login') ?? '请先登录',
            ),
          ),
        );
        return;
      }

      // 调用修改密码接口（使用本地获取的memberId）
      setState(() => _isLoading = true);
      final response = await HttpUtil.put(
        updatePassword,
        data: {
          'memberId': _memberId, // 本地获取的memberId
          'oldPassword': oldPwd,
          'newPassword': newPwd,
          'checkPassword': confirmPwd,
        },
      );

      if (response.data['code'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('pwd_update_success') ?? '密码修改成功',
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception(
          response.data['msg'] ?? 
          AppLocalizations.of(context)?.translate('pwd_update_failed') ?? 
          '密码修改失败'
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)?.translate('pwd_update_failed') ?? '修改失败'}：${e.toString()}',
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 返回栏 + 标题（样式不变）
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
                      AppLocalizations.of(context)?.translate('password_change') ?? '密码修改',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // 密码表单区域（本地数据加载完成后显示）
          Expanded(
            child: _isInfoLoading
                ? const Center(child: CircularProgressIndicator()) // 本地加载中
                : Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: ListView(
                      children: [
                        // 1. 原密码输入框
                        _buildInputItem(
                          title: AppLocalizations.of(context)?.translate('old_password') ?? '原密码',
                          hintText: AppLocalizations.of(context)?.translate('input_old_pwd') ?? '请输入原密码',
                          controller: _oldPwdController,
                          isPassword: true,
                        ),

                        // 2. 新密码输入框
                        _buildInputItem(
                          title: AppLocalizations.of(context)?.translate('new_password') ?? '新密码',
                          hintText: AppLocalizations.of(context)?.translate('input_new_pwd') ?? '请输入密码',
                          controller: _newPwdController,
                          isPassword: true,
                        ),

                        // 3. 确认密码输入框
                        _buildInputItem(
                          title: AppLocalizations.of(context)?.translate('confirm_password') ?? '确认密码',
                          hintText: AppLocalizations.of(context)?.translate('input_confirm_pwd') ?? '请再次输入密码',
                          controller: _confirmPwdController,
                          isPassword: true,
                        ),

                        // 4. 修改按钮
                        Container(
                          margin: const EdgeInsets.only(top: 60),
                          child: Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitChangePassword,
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
                                  : Text(
                                      AppLocalizations.of(context)?.translate('update') ?? '修改',
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

  // 输入项组件（左右结构，样式不变）
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
            width: 80,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}