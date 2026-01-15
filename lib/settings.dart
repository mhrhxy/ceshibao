import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart'; // 导入url_launcher
import 'dingbudaohang.dart';
import 'accountlogin.dart';
import 'paymentmethod.dart';
import 'notice.dart';
import 'main_tab.dart';
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // 打开外部链接的方法
  Future<void> _launchCustomerSupportUrl() async {
    // 客户支持链接（替换为实际链接，支持http/https/邮件/电话等）
    const url = 'https://www.kakaocorp.com/'; 
    final uri = Uri.parse(url);

    // 检查设备是否支持打开该链接
    if (await canLaunchUrl(uri)) {
      // 打开链接（使用launchMode指定打开方式）
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // 跳转到外部浏览器打开
      );
    } else {
      // 链接无法打开时的处理
      throw '无法打开链接: $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 返回栏（与之前保持一致）
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87, size: 20.w),
                  onPressed: () {
                    // 返回到首页
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const MainTab(initialIndex: 0)),
                      (route) => false, // 移除所有之前的路由
                    );
                  },
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)?.translate('settings') ?? '设置',
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

          // 设置项列表
          Expanded(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: ListView(
                children: [
                  // 1. 账户及登录（跳转页面，与之前一致）
                  _buildSettingItem(
                    title: AppLocalizations.of(context)?.translate('account_login') ?? '账户及登录',
                    suffixIcon: Icons.chevron_right,
                    onTap: () {
                      // 跳转到账户及登录页
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AccountLoginPage()),
                      );
                    },
                  ),
                  Divider(height: 1.h, indent: 0.w, color: Color(0xFFEEEEEE)),

                  // 2. 通知设置
                  _buildSettingItem(
                    title: AppLocalizations.of(context)?.translate('notification_setting') ?? '通知设置',
                    suffixIcon: Icons.chevron_right,
                    onTap: () {
                      // 跳转到通知设置页
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const notice()),
                      );
                    },
                  ),
                  Divider(height: 1.h, indent: 0.w, color: Color(0xFFEEEEEE)),

                  // 3. 支付方式管理
                  _buildSettingItem(
                    title: AppLocalizations.of(context)?.translate('payment_management') ?? '支付方式管理',
                    suffixIcon: Icons.chevron_right,
                    onTap: () {
                      // 跳转到支付方式设置页
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PaymentMethodPage()),
                      );
                    },
                  ),
                  Divider(height: 1.h, indent: 0.w, color: Color(0xFFEEEEEE)),

                  // 4. 客户支持（点击跳转链接）
                  _buildSettingItem(
                    title: AppLocalizations.of(context)?.translate('customer_support') ?? '客户支持',
                    suffixIcon: Icons.chevron_right,
                    onTap: () {
                      // 调用打开链接的方法
                      _launchCustomerSupportUrl().catchError((e) {
                        // 捕获错误并提示用户
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('无法打开链接: $e')),
                        );
                      });
                    },
                  ),
                  Divider(height: 1.h, indent: 0.w, color: Color(0xFFEEEEEE)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 原有设置项组件（不变）
  Widget _buildSettingItem({
    required String title,
    required IconData suffixIcon,
    required VoidCallback onTap,
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
            suffixIcon,
            color: Colors.grey[400],
            size: 18.w,
          ),
        ],
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      onTap: onTap,
    );
  }
}
