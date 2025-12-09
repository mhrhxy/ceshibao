import 'package:flutter/material.dart';
import 'utils/screen_adapter.dart';
import 'dingbudaohang.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'refund_application_page.dart';

class AfterSalesApplication extends StatefulWidget {
  final dynamic order;

  const AfterSalesApplication({super.key, required this.order});

  @override
  State<AfterSalesApplication> createState() => _AfterSalesApplicationState();
}

class _AfterSalesApplicationState extends State<AfterSalesApplication> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: FixedActionTopBar(),
      body: Container(
        color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
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
                      '选择退款方式',
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
            // 添加卡片组件
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.money_off_csred_outlined,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                title: const Text(
                  '退货退款 或 退款',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '点击后可申请"退货退款"或"退款（未收到货或与商家协商一致）"',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showAfterSalesTypeBottomSheet();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示底部弹出菜单
  void _showAfterSalesTypeBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF4F4F4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.zero,
          topRight: Radius.zero,
        ),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFFF4F4F4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  '请选择退款类型',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // 退货退款选项 - 白色卡片样式
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFFFF6B35),
                    size: 28,
                  ),
                  title: const Text(
                    '申请退货退款',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '已收到货，可申请退货退款。商家收货后为您处理退款，您可放心退货',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 24),
                  onTap: () {
                    Navigator.pop(context);
                    // 跳转到退货退款页面
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RefundApplicationPage(
                                orderId: widget.order.id,
                                refundType: 'return',
                                order: widget.order,
                              ),
                            ),
                          );
                  },
                ),
              ),
              // 上下间距
              const SizedBox(height: 16),
              // 仅退款选项 - 白色卡片样式
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  leading: const Icon(
                    Icons.money_off,
                    color: Color(0xFFFF6B35),
                    size: 28,
                  ),
                  title: const Text(
                    '申请退款（无需退货）',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '未收到货、已拒收快递、与商家协商一致，可申请退款',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 24),
                  onTap: () {
                    Navigator.pop(context);
                    // 跳转到仅退款页面
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RefundApplicationPage(
                                orderId: widget.order.id,
                                refundType: 'refund',
                                order: widget.order,
                              ),
                            ),
                          );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
