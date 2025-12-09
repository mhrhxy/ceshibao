// 支付方式页面
import 'package:flutter/material.dart';
import 'config/service_url.dart';
import 'utils/http_util.dart';
import 'package:dio/dio.dart'; // 导入Response类
import 'dingbudaohang.dart'; 
import 'app_localizations.dart'; // 添加国际化支持

// 支付方式数据模型
class PaymentMethod {
  final String name; // 支付类型名称
  final String payMethod; // 支付类型标识
  final String closed; // 关闭状态
  final String? logoUrl; // 支付LOGO路径
  final dynamic payMethodId; // 支付方式ID（可能是int或String）

  PaymentMethod({
    required this.name,
    required this.payMethod,
    required this.closed,
    this.logoUrl,
    this.payMethodId,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    // 从payType中获取payMethod
    final payMethodValue = json['payType']['payMethod'];
    
    // 处理closed逻辑：1表示关闭，其他或空表示开启
      final payMethodData = json['payMethod'];
      final closedValue = payMethodData != null && payMethodData['closed'] == '1' 
        ? '1' 
        : '0'; // 默认开启状态 (0表示开启，1表示关闭)
    
    // 从payMethod对象中获取payMethodId
    dynamic payMethodIdValue;
    if (payMethodData != null && payMethodData.containsKey('payMethodId')) {
      payMethodIdValue = payMethodData['payMethodId'];
    }
    
    return PaymentMethod(
      name: json['payType']['name'],
      payMethod: payMethodValue,
      closed: closedValue,
      logoUrl: json['payType']['url'],
      payMethodId: payMethodIdValue,
    );
  }
}

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  // 支付方式列表数据
  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = true; // 加载状态

  @override
  void initState() {
    super.initState();
    // 页面加载时获取支付方式数据
    _fetchPaymentMethods();
  }

  // 获取支付方式数据
  Future<void> _fetchPaymentMethods() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      Response response = await HttpUtil.get(methodlist);
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        List<dynamic> data = response.data['data'];
        setState(() {
          _paymentMethods = data.map((item) => PaymentMethod.fromJson(item)).toList();
        });
      } else {
        // 显示错误提示
        _showError(AppLocalizations.of(context).translate('get_payment_methods_failed'));
      }
    } catch (e) {
      _showError(AppLocalizations.of(context).translate('get_payment_methods_failed'));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 显示错误提示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取AppLocalizations实例
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: const FixedActionTopBar(),
      // 最外层背景直接设为白色，覆盖之前的浅灰色
      body: Container(
        color: Colors.white, // 整体内容区背景色：白色
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            // 顶部导航栏（保持原有白色背景，与内容区衔接）
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
                        localizations.translate('payment_method_settings'),
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

            // 支付方式列表区域（背景继承外层白色，无需额外设置）
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: EdgeInsets.zero, // 移除默认内边距，让列表贴边
                      children: _paymentMethods
                          .map(
                            (method) => _buildPaymentItem(
                              title: method.name,
                              isEnabled: method.closed != '1', // 1表示关闭，其他表示开启
                              onChanged: (value) => _onPaymentMethodChanged(method, value),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 支付方式开关状态变更处理
  void _onPaymentMethodChanged(PaymentMethod method, bool isEnabled) {
    String newStatus = isEnabled ? '0' : '1'; // 1表示关闭，0表示开启
    // 先更新本地状态，提供即时反馈
    setState(() {
      _paymentMethods = _paymentMethods.map((item) {
        if (item.payMethod == method.payMethod) {
          return PaymentMethod(
            name: item.name,
            payMethod: item.payMethod,
            closed: newStatus,
            logoUrl: item.logoUrl,
            payMethodId: item.payMethodId, // 保留原有的payMethodId
          );
        }
        return item;
      }).toList();
    });
    
    // 调用接口更新支付方式状态，传递完整的PaymentMethod对象
    _updatePaymentMethodStatus(method, newStatus);
  }
  
  // 更新支付方式状态接口调用
  Future<void> _updatePaymentMethodStatus(PaymentMethod paymentMethod, String closed) async {
    try {
      // 构建请求参数 - 按照接口要求使用数组格式
      List<Map<String, dynamic>> params = [
        {
          'payMethod': paymentMethod.payMethod,
          'closed': closed,
          // 只在payMethodId存在时添加该字段
          if (paymentMethod.payMethodId != null)
            'payMethodId': paymentMethod.payMethodId,
        }
      ];
      
      Response response = await HttpUtil.put(usermethod, data: params);
      
      if (response.statusCode != 200 || response.data['code'] != 200) {
        // 如果接口调用失败，恢复原状态
        print('更新支付方式状态失败: ${response.data['msg']}');
        // 重新获取支付方式数据，恢复正确状态
        _fetchPaymentMethods();
      } else {
        print('更新支付方式状态成功');
         _fetchPaymentMethods();
      }
    } catch (e) {
      print('更新支付方式状态异常: $e');
      // 异常情况下也重新获取数据
      _fetchPaymentMethods();
    }
  }

  // 封装支付方式项的通用布局（保持开关样式）
  Widget _buildPaymentItem({
    required String title,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), // 上下内边距加大，更美观
      // 底部灰色分割线（区分各项，不破坏白色背景整体感）
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!, // 浅灰色分割线
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: Colors.green, // 激活时的颜色
            inactiveThumbColor: Colors.grey, // 未激活时的圆形按钮颜色
            inactiveTrackColor: Colors.grey[200], // 未激活时的轨道颜色
            trackOutlineColor: MaterialStateProperty.all(Colors.transparent), // 移除轨道边框
          ),
        ],
      ),
    );
  }
}