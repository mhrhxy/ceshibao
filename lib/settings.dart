import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart'; // 导入url_launcher
import 'dingbudaohang.dart';
import 'accountlogin.dart';
import 'paymentmethod.dart';
import 'notice.dart';
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
                      AppLocalizations.of(context).translate('settings'),
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

          // 设置项列表
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),

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
                  const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),

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
                  const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),

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
                  const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),
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
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            suffixIcon,
            color: Colors.grey[400],
            size: 18,
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
    );
  }
}
