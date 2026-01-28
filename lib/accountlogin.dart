import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'exit_member.dart';
import 'loginto.dart';
import 'statuinfo.dart';
import 'unpdatpassword.dart';
import 'partylogin.dart';
import './config/service_url.dart'; // 仅新增接口地址依赖
import './utils/http_util.dart'; // 导入HttpUtil工具类

class AccountLoginPage extends StatefulWidget {
  const AccountLoginPage({super.key});

  @override
  State<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  bool _isLoggingOut = false; // 仅新增：注销加载状态

  // 清除登录状态（保留原有逻辑，补充清除用户信息）
  Future<void> _clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); 
    await prefs.remove('member_info'); // 新增：清除本地用户信息
    await prefs.setBool('isLogin', false);
  }

  // 新增：注销核心逻辑（调用接口+清除数据+跳转）
  Future<void> _handleLogout() async {
    if (_isLoggingOut) return; // 防止重复点击
    setState(() => _isLoggingOut = true);

    try {
      // 1. 获取本地token（用于接口验证）
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 如果没有登录（token为空），直接跳转到登录页面
      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Loginto()),
            (route) => false,
          );
        }
        return;
      }

      // 2. 调用logout接口（使用HttpUtil.post方法）
      final response = await HttpUtil.post(logout); // 使用HttpUtil统一处理网络请求

      // 接口返回非200时视为失败
      if (response.data['code'] != 200) {
        throw Exception(response.data['msg'] ?? (AppLocalizations.of(context)?.translate('logout_failed') ?? '注销失败'));
      }

      // 3. 清空本地数据
      await _clearLoginState();

      // 4. 提示并跳转登录页
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar( 
            content: Text(
              AppLocalizations.of(context)?.translate('logout_success') ?? '注销成功',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Loginto()),
          (route) => false,
        );
      }
    } catch (e) {
      // 处理异常
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.translate('logout_failed') ?? '注销失败'}：${e.toString()}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 返回栏（完全不变）
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                      AppLocalizations.of(context)?.translate('account_login') ?? '账户及登录',
                      style: TextStyle(
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
          // 功能项列表（仅修改“注销”项，其他完全不变）
          Expanded(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: ListView(
                children: [
                  // 1. 账户信息确认/变更（不变）
                  _buildAccountItem(
                    title: AppLocalizations.of(context)?.translate('account_info') ?? '账户信息确认/变更',
                    icon: Icons.person_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AccountInfoChangePage(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1.h, indent: 0, color: Color(0xFFEEEEEE)),

                  // 2. 第三方登录（不变）
                  _buildAccountItem(
                    title: AppLocalizations.of(context)?.translate('third_party_login') ?? '第三方登录',
                    icon: Icons.people_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const partylogin(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1.h, indent: 0, color: Color(0xFFEEEEEE)),

                  // 3. 密码更改（不变）
                  _buildAccountItem(
                    title: AppLocalizations.of(context)?.translate('change_password') ?? '密码更改',
                    icon: Icons.lock_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PasswordChangePage(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1.h, indent: 0, color: Color(0xFFEEEEEE)),

                  // 4. 注销（仅修改此项）
                  _buildAccountItem(
                    title: _isLoggingOut 
                        ? '${AppLocalizations.of(context)?.translate('logout') ?? '注销'}...' 
                        : AppLocalizations.of(context)?.translate('logout') ?? '注销',
                    icon: Icons.exit_to_app_outlined,
                    onTap: _isLoggingOut ? null : _handleLogout, // 加载中禁用
                  ),
                  Divider(height: 1.h, indent: 0, color: Color(0xFFEEEEEE)),

                  // 5. 退出会员（不变）
                  _buildAccountItem(
                    title: AppLocalizations.of(context)?.translate('exit_member') ?? '退出会员',
                    icon: Icons.power_settings_new_outlined,
                    onTap: () async {
                      // 检查用户是否登录
                      final prefs = await SharedPreferences.getInstance();
                      final token = prefs.getString('token');
                      if (token == null || token.isEmpty) {
                        // 未登录，跳转到登录页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Loginto(),
                          ),
                        );
                      } else {
                        // 已登录，跳转到退出会员页面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExitMemberPage(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 功能项组件（完全还原原始状态，不做任何修改）
  Widget _buildAccountItem({
    required String title,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(width: 8.w),
          Icon(
            icon,
            color: Colors.grey[400],
            size: 18.sp,
          ),
        ],
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      onTap: onTap,
    );
  }
}