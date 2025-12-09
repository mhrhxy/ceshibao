import 'package:flutter/material.dart';
import 'dingbudaohang.dart';

class RefundApplicationPage extends StatefulWidget {
  final String orderId;
  final String refundType; // 'return' 表示退货退款, 'refund' 表示仅退款

  const RefundApplicationPage({
    super.key,
    required this.orderId,
    required this.refundType,
  });

  @override
  State<RefundApplicationPage> createState() => _RefundApplicationPageState();
}

class _RefundApplicationPageState extends State<RefundApplicationPage> {
  // 根据退款类型获取页面标题
  String getPageTitle() {
    if (widget.refundType == 'return') {
      return '申请退货退款';
    } else {
      return '申请退款';
    }
  }

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
                        getPageTitle(),
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
            // 内容区域 - 暂时为空，后续可以根据需求添加
            Expanded(
              child: Center(
                child: Text(
                  '${getPageTitle()}页面内容',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}