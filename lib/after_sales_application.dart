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
                      AppLocalizations.of(context)?.translate('select_refund_method') ?? '选择退款方式',
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
                title: Text(
                  AppLocalizations.of(context)?.translate('return_refund_or_refund') ?? '退货退款 或 退款',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppLocalizations.of(context)?.translate('click_to_apply_return_refund_or_refund') ?? '点击后可申请"退货退款"或"退款（未收到货或与商家协商一致）"',
                    style: const TextStyle(
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
    // 获取订单状态和支付状态
    String orderState = '';
    String payStatus = '';
    
    // 检查widget.order是Map还是对象
    if (widget.order is Map) {
      orderState = widget.order['orderState']?.toString() ?? '';
      payStatus = widget.order['payStatus']?.toString() ?? '';
    } else {
      // 尝试从对象属性获取
      try {
        orderState = widget.order.orderState?.toString() ?? '';
        payStatus = widget.order.payStatus?.toString() ?? '';
      } catch (e) {
        print('获取订单状态失败: $e');
      }
    }
    
    print('申请售后 - 订单状态: orderState=$orderState, payStatus=$payStatus');
    
    // 根据订单状态判断可选择的退款类型
    // orderStatus 2 且 payStatus 3：仅退款/部分仅退款
    // orderStatus 3：仅退款/部分仅退款
    // orderStatus 4\5\6：所有退款类型（无需考虑payStatus）
    bool canOnlyRefund = (orderState == '2' && payStatus == '3') || orderState == '3';
    bool canReturnRefund = orderState == '4' || orderState == '5' || orderState == '6';
    
    // orderState 4/5/6 时，同时显示所有退款类型
    if (orderState == '4' || orderState == '5' || orderState == '6') {
      canOnlyRefund = true;
    }
    
    // 构建可用的退款选项列表
    List<Widget> refundOptions = [];
    
    if (canReturnRefund) {
      // 退货退款选项 - 白色卡片样式
      refundOptions.add(
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
            title: Text(
              AppLocalizations.of(context)?.translate('apply_return_refund') ?? '申请退货退款',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                AppLocalizations.of(context)?.translate('return_refund_description') ?? '已收到货，可申请退货退款。商家收货后为您处理退款，您可放心退货',
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
      );
      
      if (canOnlyRefund) {
        refundOptions.add(const SizedBox(height: 16));
      }
    }
    
    if (canOnlyRefund) {
      // 仅退款选项 - 白色卡片样式
      refundOptions.add(
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
            title: Text(
              AppLocalizations.of(context)?.translate('apply_refund_no_return') ?? '申请退款（无需退货）',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                AppLocalizations.of(context)?.translate('refund_no_return_description') ?? '未收到货、已拒收快递、与商家协商一致，可申请退款',
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
      );
    }
    
    // 如果没有任何可用的退款选项，添加提示信息
    if (refundOptions.isEmpty) {
      refundOptions.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            AppLocalizations.of(context)?.translate('current_order_status_not_support_after_sales') ?? '当前订单状态暂不支持申请售后',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
        ),
      );
    }
    
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
               Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  AppLocalizations.of(context)?.translate('please_select_refund_type') ?? '请选择退款类型',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ...refundOptions,
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
