import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mall/app_localizations.dart'; // 导入国际化工具类
import 'dingbudaohang.dart';
import 'myreview.dart';
import 'address.dart';
import 'Myorder.dart';
import 'announcement.dart';
class Mine extends StatefulWidget {
  const Mine({super.key});

  @override
  State<Mine> createState() => _MineState();
}

class _MineState extends State<Mine> {
  // 模拟用户名（实际应从用户信息中动态获取）
  final String userName = "OOO";

  // 功能选项数据（支持国际化文本动态获取）
  List<Map<String, dynamic>> get functionItems => [
    {
      "key": "notice", // 唯一标识（用于判断点击事件，不随语言变化）
      "icon": Icons.file_copy_outlined,
      "title": AppLocalizations.of(context)?.translate('notice') ?? '公告',
      "color": Colors.blue,
    },
    {
      "key": "consultation",
      "icon": Icons.chat_bubble_outline,
      "title": AppLocalizations.of(context)?.translate('one_on_one_consultation') ?? '1:1咨询',
      "color": Colors.orange,
    },
    {
      "key": "address", // 地址簿管理的唯一标识
      "icon": Icons.location_on_outlined,
      "title": AppLocalizations.of(context)?.translate('address_book_management') ?? '地址簿管理',
      "color": Colors.green,
    },
    {
      "key": "review",
      "icon": Icons.reviews_outlined,
      "title": AppLocalizations.of(context)?.translate('write_review_view') ?? '写评论 & 查看',
      "color": Colors.purple,
    },
    {
      "key": "coupon",
      "icon": Icons.card_giftcard_outlined,
      "title": AppLocalizations.of(context)?.translate('participate_event_get_coupon') ?? '参与活动领取优惠券',
      "color": Colors.indigo,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // 状态栏透明设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ));
    });

    // 获取状态栏高度
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 国际化文本获取（简化重复调用）
    String translate(String key) => AppLocalizations.of(context)?.translate(key) ?? key;

    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          // 顶部背景图片
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Image(
              image: const AssetImage('images/bjttb.png'),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
            ),
          ),

          // 主体内容
          ListView(
            padding: EdgeInsets.only(
              top: statusBarHeight + 60,
              left: 16,
              right: 16,
            ),
            children: [
              // 欢迎语（带用户名占位符）
              Text(
                translate('welcome_user').replaceAll('%s', userName),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // 黄色优惠券和积分卡片
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(translate('held_coupons'), style: const TextStyle(fontSize: 18, color: Colors.white)),
                          const SizedBox(height: 8),
                          const Text("5", style: TextStyle(fontSize: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFE0B800)),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(translate('held_points'), style: const TextStyle(fontSize: 18, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text("10000${translate('points_unit')}", style: const TextStyle(fontSize: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 订单和购物车卡片
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFB3D1FF), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildBorderedItem(translate('my_orders')),
                    Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16), color: const Color(0xFFB3D1FF)),
                    _buildBorderedItem(translate('cart_and_collect')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 功能选项列表
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFB3D1FF), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: functionItems
                      .asMap()
                      .entries
                      .map((entry) => _buildFunctionItem(
                            context: context,
                            index: entry.key,
                            total: functionItems.length,
                            icon: entry.value["icon"],
                            title: entry.value["title"],
                            color: entry.value["color"],
                            key: entry.value["key"], // 传递唯一标识用于点击判断
                          ))
                      .toList(),
                ),
              ),
            ],
          ),

          // 导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FixedActionTopBar(
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  // 构建带边框的项目
  Widget _buildBorderedItem(String title) {
    // 获取翻译文本
    String myOrdersTitle = AppLocalizations.of(context)?.translate('my_orders') ?? '我的订单';
    
    return GestureDetector(
      onTap: () {
        if (title == myOrdersTitle) {
          // 跳转到我的订单页面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Myorder(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建功能选项Item（添加地址簿管理的跳转逻辑）
  Widget _buildFunctionItem({
    required BuildContext context,
    required int index,
    required int total,
    required IconData icon,
    required String title,
    required Color color,
    required String key, // 唯一标识
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            // 根据唯一key判断跳转，不受语言切换影响
            if (key == "review") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyCommentsPage(),
                ),
              );
            } else if (key == "address") { // 地址簿管理的跳转逻辑
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>  AddressBookPage(), // 跳转到新增收货地址页面
                ),
              );
            }else if (key == "notice") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoticePage(), // 跳转到公告页面
                ),
              );
            }
            // 其他功能项可按key扩展点击逻辑（示例）
            // else if (key == "notice") { /* 跳转公告页面 */ }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Color(0xFF999999), size: 18),
              ],
            ),
          ),
        ),
        if (index != total - 1)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFFF0F0F0),
          ),
      ],
    );
  }
}