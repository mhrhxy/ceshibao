import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'dingbudaohang.dart';
import 'utils/http_util.dart';
import 'config/service_url.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'after_sales_application.dart';
// 我的订单页
// 支付方式数据模型·
class PaymentMethod {
  final String name;
  final String url;

  PaymentMethod({required this.name, required this.url});
}

class PayCard {
  final int payCardId;
  final String payMethod;
  final String url;
  final String name;
  final String nameCode;

  PayCard({
    required this.payCardId,
    required this.payMethod,
    required this.url,
    required this.name,
    required this.nameCode,
  });

  factory PayCard.fromJson(Map<String, dynamic> json) {
    return PayCard(
      payCardId: json['payCardId'],
      payMethod: json['payMethod'],
      url: json['url'],
      name: json['name'],
      nameCode: json['nameCode'],
    );
  }
}
class Myorder extends StatefulWidget {
  const Myorder({Key? key}) : super(key: key);

  @override
  State<Myorder> createState() => _MyorderState();
}

class _MyorderState extends State<Myorder> {
  // 选中的支付卡ID
  int? _selectedCardId;
  
  // 获取支付卡列表的方法
  Future<List<PayCard>> _fetchPayCards() async {
    try {
      // 调用cardlist接口，参数payMethod=2
      var response = await HttpUtil.get(cardlist);
      
      if (response.statusCode == 200) {
        List<PayCard> cards = [];
        List<dynamic> dataList = response.data['data'] ?? [];
        
        for (var item in dataList) {
          // 只添加未删除的卡片（delFlag为0）
          if (item['delFlag'] == '0') {
            cards.add(PayCard.fromJson(item));
          }
        }
        
        // 默认选中第一个卡片
        if (cards.isNotEmpty) {
          setState(() {
            _selectedCardId = cards.first.payCardId;
          });
        }
        
        return cards;
      } else {
        throw Exception('Failed to fetch pay cards');
      }
    } catch (e) {
      print('Error fetching pay cards: $e');
      throw e;
    }
  }
  
  // 构建卡片列表UI
  Widget _buildCardList(List<PayCard> cards) {
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final isSelected = _selectedCardId == card.payCardId;
        
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCardId = card.payCardId;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧：卡片名称和图片
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      card.url.isNotEmpty 
                        ? Image.network('$baseUrl${card.url}', width: 100, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 100, height: 60, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey)))
                        : Container(),
                    ],
                  ),
                  // 右侧：选择框
                  Radio(
                    value: card.payCardId,
                    groupValue: _selectedCardId,
                    onChanged: (value) {
                      setState(() {
                        _selectedCardId = value as int;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // 订单状态数据
  List<Map<String, dynamic>> orderStatusList = [];

  // 当前选中的状态索引
  int currentStatusIndex = -1;
  
  // 全部订单数量
  int totalOrderCount = 0;
  
  // 订单数据
  List<OrderData> orderList = [];
  
  // 不需要分页相关变量
  
  // 加载中状态
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // 初始化时加载所有订单
    loadOrderList(0, 0, true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在didChangeDependencies中初始化，此时context完全可用
    orderStatusList = [
      {'name': AppLocalizations.of(context)?.translate('payment_ended') ?? '付款结束', 'count': 2, 'orderState': 2, 'orderPayState': 3},
      {'name': AppLocalizations.of(context)?.translate('warehouse_in_ended') ?? '入库结束', 'count': 3, 'orderState': 5, 'orderPayState': 0},
      {'name': AppLocalizations.of(context)?.translate('warehouse_out_pending') ?? '出库待发', 'count': 4, 'orderState': 6, 'orderPayState': 0},
      {'name': AppLocalizations.of(context)?.translate('shipped_complete') ?? '发货完成', 'count': 5, 'orderState': 7, 'orderPayState': 0},
      {'name': AppLocalizations.of(context)?.translate('cancel_order') ?? '取消订单', 'count': 6, 'orderState': -1, 'orderPayState': 0},
    ];
  }

  // 根据订单状态获取显示文字和颜色
  Map<String, dynamic> getOrderStatusInfo(String orderState, String payStatus) {
    String statusText = AppLocalizations.of(context)?.translate('unknown_status') ?? '未知状态';
    Color statusColor = Colors.grey;
    
    switch(orderState) {
      case '1':
        statusText = AppLocalizations.of(context)?.translate('pending_payment') ?? '待支付';
        statusColor = Colors.orange;
        break;
      case '2':
        statusText = AppLocalizations.of(context)?.translate('paid') ?? '已支付';
        statusColor = Colors.green;
        break;
      case '3':
        statusText = AppLocalizations.of(context)?.translate('pending_shipment') ?? '待发货';
        statusColor = Colors.blue;
        break;
      case '4':
        statusText = AppLocalizations.of(context)?.translate('shipping') ?? '发货中';
        statusColor = Colors.blueAccent;
        break;
      case '5':
        statusText = AppLocalizations.of(context)?.translate('warehouse_in') ?? '已入库';
        statusColor = Colors.purple;
        break;
      case '6':
        statusText = AppLocalizations.of(context)?.translate('warehouse_out_pending') ?? '出库待发';
        statusColor = Colors.purpleAccent;
        break;
      case '7':
        statusText = AppLocalizations.of(context)?.translate('shipped_complete') ?? '发货完成';
        statusColor = Colors.indigo;
        break;
      case '8':
          statusText = AppLocalizations.of(context)?.translate('arrived') ?? '已到货';
        statusColor = Colors.teal;
        break;
      case '9':
        statusText = AppLocalizations.of(context)?.translate('completed') ?? '已完成';
        statusColor = Colors.greenAccent;
        break;
      case '-1':
        statusText = AppLocalizations.of(context)?.translate('cancelled') ?? '已取消';
        statusColor = Colors.red;
        break;
      case '-2':
        statusText = AppLocalizations.of(context)?.translate('order_exception') ?? '订单异常';
        statusColor = Colors.redAccent;
        break;
    }
    
    return {'text': statusText, 'color': statusColor};
  }

  // 根据订单状态获取背景色
  Color getStatusBackgroundColor(String status) {
    final loc = AppLocalizations.of(context);
    
    if (status == (loc?.translate('pending_payment') ?? '待支付')) {
      return Colors.orange.withOpacity(0.1);
    } else if (status == (loc?.translate('paid') ?? '已支付')) {
      return Colors.green.withOpacity(0.1);
    } else if (status == (loc?.translate('pending_shipment') ?? '待发货')) {
      return Colors.blue.withOpacity(0.1);
    } else if (status == (loc?.translate('shipping') ?? '发货中')) {
      return Colors.blueAccent.withOpacity(0.1);
    } else if (status == (loc?.translate('warehouse_in') ?? '已入库')) {
      return Colors.purple.withOpacity(0.1);
    } else if (status == (loc?.translate('warehouse_out_pending') ?? '出库待发')) {
      return Colors.purpleAccent.withOpacity(0.1);
    } else if (status == (loc?.translate('shipped_complete') ?? '发货完成')) {
      return Colors.indigo.withOpacity(0.1);
    } else if (status == (loc?.translate('arrived') ?? '已到货')) {
      return Colors.teal.withOpacity(0.1);
    } else if (status == (loc?.translate('completed') ?? '已完成')) {
      return Colors.greenAccent.withOpacity(0.1);
    } else if (status == (loc?.translate('cancelled') ?? '已取消')) {
      return Colors.transparent; // 无背景色
    } else if (status == (loc?.translate('order_exception') ?? '订单异常')) {
      return Colors.redAccent.withOpacity(0.1);
    } else {
      return Colors.grey.withOpacity(0.1);
    }
  }

  // 根据订单状态获取文字颜色
  Color getStatusTextColor(String status) {
    final loc = AppLocalizations.of(context);
    
    if (status == (loc?.translate('pending_payment') ?? '待支付')) {
      return Colors.orange;
    } else if (status == (loc?.translate('paid') ?? '已支付')) {
      return Colors.green;
    } else if (status == (loc?.translate('pending_shipment') ?? '待发货')) {
      return Colors.blue;
    } else if (status == (loc?.translate('shipping') ?? '发货中')) {
      return Colors.blueAccent;
    } else if (status == (loc?.translate('warehouse_in') ?? '已入库')) {
      return Colors.purple;
    } else if (status == (loc?.translate('warehouse_out_pending') ?? '出库待发')) {
      return Colors.purpleAccent;
    } else if (status == (loc?.translate('shipped_complete') ?? '发货完成')) {
      return Colors.indigo;
    } else if (status == (loc?.translate('arrived') ?? '已到货')) {
      return Colors.teal;
    } else if (status == (loc?.translate('completed') ?? '已完成')) {
      return Colors.greenAccent;
    } else if (status == (loc?.translate('cancelled') ?? '已取消')) {
      return Colors.black; // 使用纯黑色文字
    } else if (status == (loc?.translate('order_exception') ?? '订单异常')) {
      return Colors.redAccent;
    } else {
      return Colors.grey;
    }
  }
  
  // 格式化价格
  String formatPrice(double price, String currency) {
    if (currency == 'RMB' || currency == 'CNY') {
      return '¥${price.toStringAsFixed(2)}';
    } else {
      return '₩${price.toStringAsFixed(2)}';
    }
  }
  
  // 加载订单列表
  Future<void> loadOrderList(int orderState, int orderPayState, bool isRefresh) async {
    if (isLoading) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      Map<String, dynamic> params = {
        'orderState': orderState,
        'orderPayState': orderPayState
      };
      
      var response = await HttpUtil.get(searchOrderListUrl, queryParameters: params);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        if (data['code'] == 200) {
          List<OrderData> newOrders = [];
          
          for (var item in data['data']) {
            // 获取订单状态信息
            var statusInfo = getOrderStatusInfo(item['orderState'], item['payStatus']);
            
            // 创建订单数据对象
            OrderData order = OrderData(
              id: item['orderId'].toString(),
              title: '', // 初始为空，后续从orderItems中获取
              count: item['num'] ?? 1,
              status: statusInfo['text'],
              statusColor: statusInfo['color'],
              price: formatPrice(item['productAllPrice'] ?? 0, item['currency'] ?? 'RMB'),
              description: '',
              imageUrl: '', // 初始为空，后续从orderItems中获取
              isExpanded: false,
              orderOriginNo: item['orderOriginNo'].toString(),
              address: '${item['address']}',
              recipient: '${item['receiveName']} ${item['mobilePhone']}',
              orderItems: [],
              outerPurchaseId: item['outerPurchaseId'],
              productAllPrice: item['productAllPrice'] ?? 0,
              currency: item['currency'] ?? 'RMB',
              shopName: item['shopName'],
              orderState: item['orderState'].toString(),
              payStatus: item['payStatus'].toString(),
              feeSea: item['feeSea'] ?? 0.0
            );
            
            newOrders.add(order);
            // 立即加载订单项详情
            loadOrderProducts(order.id);
          }
          
          setState(() {
            orderList = newOrders;
          });
          
          // 如果是全部订单，同时更新各状态的数量
          if (orderState == 0 && orderPayState == 0) {
            updateOrderStatusCounts();
          }
        }
      }
    } catch (e) {
      print('${AppLocalizations.of(context)?.translate('load_order_list_failed') ?? '加载订单列表失败'}: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
      
      // 加载完成
    }
  }
  
  // 更新各订单状态的数量
  void updateOrderStatusCounts() {
    // 更新全部订单数量
    totalOrderCount = orderList.length;
    
    // 重置所有计数为0
    for (var status in orderStatusList) {
      status['count'] = 0;
    }
    
    // 遍历所有订单，根据状态更新计数
    for (var order in orderList) {
      String orderState = order.status;
      
      // 根据订单状态文本匹配对应的状态项
      for (var status in orderStatusList) {
        if (orderState.contains(status['name'])) {
          status['count']++;
        } else if (orderState == (AppLocalizations.of(context)?.translate('cancelled') ?? '已取消') && status['name'] == (AppLocalizations.of(context)?.translate('cancel_order') ?? '取消订单')) {
          status['count']++;
        }
      }
    }
    
    // 触发UI更新
    setState(() {});
  }
  
  // 加载订单项详情
  Future<void> loadOrderProducts(String orderId) async {
    try {
      Map<String, dynamic> params = {'orderIds': orderId};
      var response = await HttpUtil.get(searchOrderProductListUrl, queryParameters: params);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        if (data['code'] == 200) {
          List<OrderItem> orderItems = [];
          
          for (var item in data['data']) {
            // 解析规格信息
            // 解析规格信息的核心代码
            String specsText = '';
            if (item['sku'] != null && item['sku'].toString().isNotEmpty) {
              try {
                var secJson = json.decode(item['sku']);
                if (secJson['properties'] != null && secJson['properties'] is List) {
                  List properties = secJson['properties'];
                  if (properties.isNotEmpty) {
                    specsText = properties.map((p) => p['value_name']).where((v) => v != null && v.toString().isNotEmpty).join(' ');
                  }
                }
              } catch (e) {
                print('解析规格信息失败: $e');
                // 如果解析失败，回退到使用sku字段
                specsText = item['sku'] ?? '';
              }
            } else {
              // 如果没有sec字段，使用sku字段
              specsText = item['sku'] ?? '';
            }
            
            OrderItem orderItem = OrderItem(
              name: item['titleCn'] ?? item['titleEn'] ?? AppLocalizations.of(context)?.translate('product') ?? '商品',
              color: specsText,
              quantity: item['quantity'] ?? 1,
              price: formatPrice(item['price'] ?? 0, 'RMB'), // 假设价格单位是元
              imageUrl: item['imgUrl']?.replaceAll(' ', '') ?? 'https://img.alicdn.com/bao/uploaded/i4/2214969080592/O1CN01chogkv1GFBG0iYKFj_!!2214969080592.png',
            );
            
            orderItems.add(orderItem);
          }
          
          // 更新对应订单的商品列表
          setState(() {
            for (var order in orderList) {
              if (order.id == orderId) {
                order.orderItems = orderItems;
                if (orderItems.isNotEmpty) {
                  order.title = orderItems[0].name;
                  order.imageUrl = orderItems[0].imageUrl;
                }
                break;
              }
            }
          });
        }
      }
    } catch (e) {
      print('${AppLocalizations.of(context)?.translate('load_order_items_failed') ?? '加载订单商品失败'}: $e');
    }
  }

  // 切换订单项的展开/折叠状态
  void toggleExpand(String orderId) {
    setState(() {
      for (var order in orderList) {
        if (order.id == orderId) {
          order.isExpanded = !order.isExpanded;
          // 展开时加载商品详情
          if (order.isExpanded && order.orderItems.isEmpty) {
            loadOrderProducts(orderId);
          }
        }
      }
    });
  }


  
  void _cancelOrder(String orderId) async {
    try {
      // 调用取消订单接口（使用PUT请求）
      var response = await HttpUtil.put('$cancelOrderUrl$orderId', data: null);
      
      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        if (data['code'] == 200) {
          // 接口调用成功，更新本地状态
          setState(() {
            // 找到要取消的订单并更新状态
            final order = orderList.firstWhere((o) => o.id == orderId);
            order.status = AppLocalizations.of(context)?.translate('cancelled') ?? '已取消'; // 更新状态为已取消
          });
          
          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.translate('order_already_cancelled') ?? '订单已取消')),
          );
          
          // 重新加载订单列表以获取最新状态
          onRefresh();
        } else {
          // 接口返回错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context)?.translate('cancel_failed') ?? '取消失败'}: ${data['message'] ?? (AppLocalizations.of(context)?.translate('unknown_error') ?? '未知错误')}')),
          );
        }
      } else {
        // 网络请求失败
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.translate('network_request_failed') ?? '网络请求失败，请稍后重试')),
        );
      }
    } catch (e) {
      // 捕获异常
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取消订单失败，请稍后重试')),
      );
    }
  }
  
  // 立即支付的方法
  // 使用选定的支付卡处理支付
  // NaverPay支付方法
  Future<void> _processPaymentWithNaverpay(String orderId, {double? customAmount}) async {
    try {
      // 根据orderId查找对应的订单数据
      OrderData? orderData;
      try {
        orderData = orderList.firstWhere((order) => order.id == orderId);
      } catch (e) {
        orderData = null;
      }
      
      if (orderData == null) {
        throw Exception('找不到对应订单信息');
      }
      
      // 查询美元汇率
      dynamic usdRate = 0.14; // 默认汇率，防止接口调用失败
      try {
        var rateResponse = await HttpUtil.get(searchRateUrl, queryParameters: {
          'currency': 3,  // 美元
          'type': 1,
          'benchmarkCurrency': 1  // 人民币
        });
        
        if (rateResponse.statusCode == 200 && rateResponse.data['code'] == 200) {
          usdRate = rateResponse.data['data'];
        }
        print('美元汇率查询成功: $usdRate');
      } catch (e) {
        print('查询汇率失败: $e');
      }
      
      // 计算美元金额：人民币 * 汇率，保留两位小数
      // ignore: unnecessary_type_check
      double rmbAmount = customAmount ?? (orderData.productAllPrice is double
          ? orderData.productAllPrice
          : double.tryParse(orderData.productAllPrice.toString()) ?? 0.0);
      double usdAmount = double.parse((rmbAmount * usdRate).toStringAsFixed(2)); // 保留两位小数
      
      // 构建请求参数，使用实际订单数据
      Map<String, dynamic> requestData = {
        "payCommon": {
          "orderId": int.tryParse(orderData.id), // 订单ID
          "type": 1, // 支付类型，NaverPay默认传1
          "payCost": usdAmount.toString(), // 支付金额（转换为美元，保留两位小数）
          "orderNo": orderData.orderOriginNo, // 订单编号
          "paymentRedirectUrl": "flutterappxm://pay/callback?orderNo=${orderData.orderOriginNo}",
        }
      };
      print('NaverPay支付请求参数: $requestData');

      // 调用NaverPay支付接口
      print('调用NaverPay支付接口，订单ID: $orderId');
      var response = await HttpUtil.post(naverpay, data: requestData);

      // 处理接口返回
      if (response.data['code'] == 200 && response.data['data'] != null) {
        String redirectUrl = response.data['data']['redirectUrl'];
        String paymentRequestId = response.data['data']['paymentRequestId'];
        
        print('NaverPay支付跳转URL: $redirectUrl');
        print('NaverPay支付请求ID: $paymentRequestId');
        
        // 使用url_launcher跳转到第三方支付页面
        if (await canLaunchUrl(Uri.parse(redirectUrl))) {
          await launchUrl(Uri.parse(redirectUrl), mode: LaunchMode.externalApplication);
          
          // 支付后返回应用，显示中性提示并刷新订单列表以检查实际支付状态
          Future.delayed(const Duration(seconds: 1), () {
            // 显示提示信息
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                content: Text(AppLocalizations.of(context)?.translate('check_order_status_for_payment_result') ?? '请查看订单状态确认支付结果'),
                duration: Duration(seconds: 2),
              ),
            );
            
            // 重新加载订单数据以获取最新支付状态
            onRefresh();
          });
        } else {
          throw Exception('无法打开支付页面');
        }
      } else {
        throw Exception('支付失败');
      }
    } catch (e) {
      print('NaverPay支付失败: $e');
      // 显示支付失败提示
      showDialog(
        context: context, 
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)?.translate('payment_failed') ?? '支付失败'),
              content: Text(AppLocalizations.of(context)?.translate('please_wait_patiently') ?? '请耐心等待'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确定')
                )
          ],
        )
      );
    }
  }

  // 卡支付方法
  Future<void> _processPaymentWithCard(String orderId, int payCardId, {double? customAmount}) async {
    try {
      // 根据orderId查找对应的订单数据
      OrderData? orderData;
      try {
        orderData = orderList.firstWhere((order) => order.id == orderId);
      } catch (e) {
        orderData = null;
      }
      
      if (orderData == null) {
        throw Exception('找不到对应订单信息');
      }
      
      // 先查询韩元汇率
      dynamic koreanWonRate = 14700; // 默认汇率，防止接口调用失败
      try {
        var rateResponse = await HttpUtil.get(searchRateUrl, queryParameters: {
          'currency': 2,  // 韩元
          'type': 1,
          'benchmarkCurrency': 1  // 人民币
        });
        
        if (rateResponse.statusCode == 200 && rateResponse.data['code'] == 200) {
          koreanWonRate = rateResponse.data['data'];
        }
        print('韩元汇率查询成功: $koreanWonRate');
      } catch (e) {
        print('查询汇率失败: $e');
      }
      
      // 计算韩元金额：人民币 * 汇率，去掉小数和个位数
      // ignore: unnecessary_type_check
      double rmbAmount = customAmount ?? (orderData.productAllPrice is double
          ? orderData.productAllPrice
          : double.tryParse(orderData.productAllPrice.toString()) ?? 0.0);
      int krwAmount = ((rmbAmount * koreanWonRate) ~/ 10) * 10; // 去掉个位数
      
      // 构建请求参数，使用实际订单数据
      Map<String, dynamic> requestData = {
        "payCommon": {
          "orderId": int.tryParse(orderData.id), // 订单ID
          "type": 2, // 支付类型，卡支付默认传2
          "payCost": krwAmount.toString(), // 支付金额（转换为韩元）
          "orderNo": orderData.orderOriginNo, // 订单编号
          "paymentRedirectUrl": "flutterappxm://pay/callback?orderNo=${orderData.orderOriginNo}",
        },
        "cardBrand": "KAKAOBANK", // 卡银行
        "isCardNormal": 1 // 是否通用银行卡
      };
      print('支付请求参数: $requestData');

      // 调用卡支付接口
      print('调用卡支付接口，订单ID: $orderId, 支付卡ID: $payCardId');
      var response = await HttpUtil.post(cardpay, data: requestData);

      // 处理接口返回
      if (response.data['code'] == 200 && response.data['data'] != null) {
        String redirectUrl = response.data['data']['redirectUrl'];
        String paymentRequestId = response.data['data']['paymentRequestId'];
        
        print('支付跳转URL: $redirectUrl');
        print('支付请求ID: $paymentRequestId');
        
        // 使用url_launcher跳转到第三方支付页面
        if (await canLaunchUrl(Uri.parse(redirectUrl))) {
          await launchUrl(Uri.parse(redirectUrl), mode: LaunchMode.externalApplication);
          
          // 支付完成后，提示用户已返回应用并刷新订单列表
          Future.delayed(const Duration(seconds: 3), () {
            // 显示提示信息
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                content: Text(AppLocalizations.of(context)?.translate('payment_completed') ?? '支付已完成'),
                duration: Duration(seconds: 2),
              ),
            );
            
            // 重新加载订单数据
            onRefresh();
          });
        } else {
          throw Exception('无法打开支付页面');
        }
      } else {
        throw Exception('支付失败');
      }
    } catch (e) {
      print('支付失败: $e');
      // 显示支付失败提示
      showDialog(
        context: context, 
        builder: (context) => AlertDialog(
          title: Text('支付失败'),
          content: Text('请耐心等待'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('确定')
            )
          ],
        )
      );
    }
  }

  Future<void> _showCardSelectionModal(BuildContext context, String orderId, {double? customAmount}) async {
    // 显示从底部弹出的卡片选择窗口
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 顶部标题和关闭按钮
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)?.translate('select_payment_card') ?? '选择支付卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              // 卡片列表
              Expanded(
                child: FutureBuilder<List<PayCard>>(
                  future: _fetchPayCards(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text(AppLocalizations.of(context)?.translate('get_payment_cards_failed') ?? '获取支付卡失败'));
                    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return _buildCardList(snapshot.data!);
                    } else {
                      return Center(child: Text(AppLocalizations.of(context)?.translate('no_available_payment_cards') ?? '暂无可用支付卡'));
                    }
                  },
                ),
              ),
              // 确认按钮
              Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    // 处理确认选择
                    if (_selectedCardId != null) {
                      // 这里可以添加支付逻辑，使用选中的支付卡ID
                      print('选中的支付卡ID: $_selectedCardId');
                      // 可以调用支付接口
                      _processPaymentWithCard(orderId, _selectedCardId!, customAmount: customAmount);
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确认', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 支付运费的方法
  void _payShippingFee(String orderId, double shippingFee) async {
    // 显示支付方式弹窗
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)?.translate('select_payment_method') ?? '选择支付方式'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<PaymentMethod>>(
              future: _fetchPaymentMethods(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text(AppLocalizations.of(context)?.translate('get_payment_methods_failed') ?? '获取支付方式失败'));
                } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final payment = snapshot.data![index];
                      return Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: InkWell(
                            onTap: () {
                              // 根据支付方式类型调用不同的支付方法
                              if (payment.name == '卡支付') {
                                Navigator.of(context).pop();
                                _showCardSelectionModal(context, orderId, customAmount: shippingFee);
                              } else if (payment.name == 'Naver支付') {
                                Navigator.of(context).pop();
                                _processPaymentWithNaverpay(orderId, customAmount: shippingFee);
                              }
                            },
                            child: Column(
                              children: [
                                Text(payment.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 10),
                                payment.url.isNotEmpty ? Image.network(payment.url, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey))): Container(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Center(child: Text(AppLocalizations.of(context)?.translate('no_available_payment_methods') ?? '暂无可用支付方式'));
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.translate('disabled') ?? '关闭'),
            ),
          ],
        );
      },
    );
  }

  void _payOrder(String orderId) async {
    // 显示支付方式弹窗
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)?.translate('select_payment_method') ?? '选择支付方式'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<PaymentMethod>>(
              future: _fetchPaymentMethods(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text(AppLocalizations.of(context)?.translate('get_payment_methods_failed') ?? '获取支付方式失败'));
                } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final payment = snapshot.data![index];
                      return Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: InkWell(
                            onTap: () async {
                              // 根据支付方式类型调用不同的支付方法
                              if (payment.name == '卡支付') {
                                Navigator.of(context).pop();
                                // 等待支付操作完成
                                await _showCardSelectionModal(context, orderId, customAmount: null);
                                // 支付完成后刷新订单列表
                                onRefresh();
                              } else if (payment.name == 'Naver支付') {
                                Navigator.of(context).pop();
                                // 等待支付操作完成
                                await _processPaymentWithNaverpay(orderId);
                                // 支付完成后刷新订单列表
                                onRefresh();
                              }
                            },
                            child: Column(
                              children: [
                                Text(payment.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 10),
                                payment.url.isNotEmpty ? Image.network(payment.url, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey))) : Container(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Center(child: Text(AppLocalizations.of(context)?.translate('no_available_payment_methods') ?? '暂无可用支付方式'));
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)?.translate('disabled') ?? '关闭'),
            ),
          ],
        );
      },
    );
  }

  // 获取支付方式列表
  Future<List<PaymentMethod>> _fetchPaymentMethods() async {
    try {
      Response response = await HttpUtil.get(methodlist);
      if (response.statusCode == 200) {
        List<PaymentMethod> paymentMethods = [];
        List<dynamic> data = response.data['data'];
        
        for (var item in data) {
          // 检查payMethod是否为null，以及closed字段是否不是'1'
          bool shouldShow = true;
          // if (item['payMethod'] != null && item['payMethod']['closed'] == '1') {
          //   shouldShow = false;
          // }
          
          if (shouldShow) {
            String name = item['payType']['name'] ?? '';
            String url = item['payType']['url'] ?? '';
            // 如果url不是完整的http地址，需要拼接baseUrl
            if (url.isNotEmpty && !url.startsWith('http')) {
              url = 'http://192.168.0.120:8080' + url;
            }
            paymentMethods.add(PaymentMethod(name: name, url: url));
          }
        }
        
        return paymentMethods;
      }
    } catch (e) {
      print('获取支付方式失败: $e');
    }
    return [];
  }
  
  // 申请售后
  void _applyAfterSales(dynamic order) {
    // 跳转到售后申请页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AfterSalesApplication(order: order),
      ),
    );
  }

  // 切换订单状态
  void changeOrderStatus(int index) {
    setState(() {
      currentStatusIndex = index;
    });
    
    // 根据索引获取状态参数
    Map<String, dynamic> status = {};
    if (index == -1) {
      // 全部订单
      status = {'orderState': 0, 'orderPayState': 0};
    } else {
      status = orderStatusList[index];
    }
    
    // 重新加载订单列表
    loadOrderList(status['orderState'], status['orderPayState'], true);
  }
  
  // 下拉刷新
  Future<void> onRefresh() async {
    Map<String, dynamic> status = {};
    if (currentStatusIndex == -1) {
      status = {'orderState': 0, 'orderPayState': 0};
    } else {
      status = orderStatusList[currentStatusIndex];
    }
    await loadOrderList(status['orderState'], status['orderPayState'], true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 44,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  AppLocalizations.of(context)?.translate('my_orders') ?? "我的订单",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
              ],
            ),
          ),
          // 订单状态选项卡
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 全部订单选项
                  GestureDetector(
                    onTap: () => changeOrderStatus(-1),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 15),
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)?.translate('all_orders') ?? '全部订单',
                            style: TextStyle(fontSize: 14, color: currentStatusIndex == -1 ? Colors.blue : Colors.black),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            totalOrderCount.toString(),
                            style: const TextStyle(fontSize: 16, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 其他状态选项
                  ...orderStatusList.asMap().entries.map((entry) {
                    int index = entry.key;
                    var status = entry.value;
                    return GestureDetector(
                      onTap: () => changeOrderStatus(index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Column(
                          children: [
                            Text(
                              status['name'],
                              style: TextStyle(fontSize: 14, color: currentStatusIndex == index ? Colors.blue : Colors.black),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              status['count'].toString(),
                              style: const TextStyle(fontSize: 16, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 筛选标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                // 左侧的"모든주문"标签 - 去掉圆角
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.zero, // 去掉圆角
                  ),
                  child: Text(AppLocalizations.of(context)?.translate('all_orders_kr') ?? '모든주문', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(), // 使用Spacer将直购和推荐标签推到右侧
                // 右侧的直购和推荐标签
                Row(
                  children: [
                    // 直购标签 - 未选中状态，增加宽度
                    Row(
                      children: [
                        Container(
                          width: 50, // 增加宽度
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(AppLocalizations.of(context)?.translate('direct_purchase') ?? '直购', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 15),
                    // 推荐标签 - 选中状态，增加宽度
                    Row(
                      children: [
                        Container(
                          width: 50, // 增加宽度
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 241, 113, 156),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(AppLocalizations.of(context)?.translate('recommended') ?? '推荐', style: const TextStyle(fontSize: 12, color: Colors.pink)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 订单列表
          Expanded(
            child: isLoading ?
              const Center(child: CircularProgressIndicator()) :
              orderList.isEmpty ?
                Center(child: Text(AppLocalizations.of(context)?.translate('no_order_data') ?? '暂无订单数据')) :
                RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    itemCount: orderList.length,
                    itemBuilder: (context, index) {
                final order = orderList[index];
                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  color: const Color.fromRGBO(249, 250, 251, 1), // #F9FAFB
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 订单头部
                      GestureDetector(
                        onTap: () {
                          toggleExpand(order.id);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 商品图片
                              Image.network(
                                order.imageUrl.isEmpty ? 'https://img.alicdn.com/bao/uploaded/i4/2214969080592/O1CN01chogkv1GFBG0iYKFj_!!2214969080592.png' : order.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                              ),
                              const SizedBox(width: 8),
                              // 商品信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 店铺名称
                                    Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // 店铺名称 - 设置为最多显示两行并在超出时显示省略号
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Text(order.shopName ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: true,
                                            ),
                                          ),
                                          const SizedBox(width: 4), // 添加小间距使布局更协调
                                          // 蓝色圆形数量标签
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.blue,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text('${order.count}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 5),
                                    // 价格
                                    Text(order.price, style: const TextStyle(fontSize: 16, color: Colors.red)),
                                  ],
                                ),
                              ),
                              // 右侧状态、按钮和箭头的水平布局
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // 蓝框内的垂直布局：订单状态和取消订单按钮（居中对齐）
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 订单状态 - 无边框无背景，纯文本显示
                                      Text(order.status, style: TextStyle(
                                        fontSize: 12,
                                        color: getStatusTextColor(order.status),
                                      )),
                                      const SizedBox(height: 4),
                                      // 取消订单按钮（只有待支付状态显示）
                                      order.status == (AppLocalizations.of(context)?.translate('pending_payment') ?? '待支付') ? Column(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              // 取消订单的逻辑
                                              _cancelOrder(order.id);
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            ),
                                            child: Text(AppLocalizations.of(context)?.translate('cancel_order') ?? '取消订单', style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            )),
                                          ),
                                          const SizedBox(height: 4),
                                          // 立即支付按钮（只有待支付状态显示）
                                          TextButton(
                                            onPressed: () {
                                              // 立即支付的逻辑
                                              _payOrder(order.id);
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            ),
                                            child: Text(AppLocalizations.of(context)?.translate('pay_now') ?? '立即支付', style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                            )),
                                          ),
                                        ],
                                      ) : 
                                      // 运费支付按钮（只有orderState等于5并且payStatus等于3时显示）
                                      (order.orderState == '5' && order.payStatus == '3') ? Column(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              // 运费支付的逻辑
                                              _payShippingFee(order.id, order.feeSea);
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            ),
                                            child: Text(AppLocalizations.of(context)?.translate('pay_shipping_fee') ?? '支付运费', style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                            )),
                                          ),
                                        ],
                                      ) : 
                                      // 申请售后按钮（只有orderState等于8并且payStatus等于4时显示）
                                      (order.orderState == '8' && order.payStatus == '4') ? Column(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              // 申请售后的逻辑
                                              _applyAfterSales(order);
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            ),
                                            child: Text(AppLocalizations.of(context)?.translate('apply_after_sales') ?? '申请售后', style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue,
                                            )),
                                          ),
                                        ],
                                      ) : Container(),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  // 展开/收起箭头 - 保持不变
                                  Icon(
                                    order.isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 展开的订单详情
                      if (order.isExpanded)
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 配送地址 - 添加灰色背景和圆角
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLocalizations.of(context)?.translate('shipping_address') ?? '配送地址', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black)),
                                    const SizedBox(height: 5),
                                    Text(order.address, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                                    Text('${AppLocalizations.of(context)?.translate('recipient') ?? '收件人'}: ${order.recipient}', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                  ],
                                ),
                              ),

                              // 订单商品列表
                      order.orderItems.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            children: order.orderItems.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[100]!),
                              ),
                              child: Row(
                                children: [
                                  // 商品图片
                                  Image.network(
                                    item.imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 12),
                                  // 商品信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(item.name, 
                                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(item.color.isNotEmpty ? item.color : (AppLocalizations.of(context)?.translate('no_specification') ?? '无规格'), 
                                          style:  TextStyle(fontSize: 14, color: Colors.grey[600])
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(item.price, 
                                              style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w500)
                                            ),
                                            Text('x${item.quantity}', 
                                              style:  TextStyle(fontSize: 15, color: Colors.grey[600])
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          )
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          ),
        ]
      ),
    );
  }
}

// 订单数据模型
class OrderData {
  String id;
  String title;
  int count;
  String status;
  Color statusColor;
  String price;
  String description;
  String imageUrl;
  bool isExpanded;
  String address;
  String recipient;
  List<OrderItem> orderItems;
  String? outerPurchaseId;
  double productAllPrice;
  String currency;
  String? shopName;
  String orderOriginNo;
  String orderState; // 订单状态编号
  String payStatus; // 支付状态编号
  double feeSea; // 海外运费

  OrderData({
    required this.id,
    required this.title,
    required this.count,
    required this.status,
    required this.statusColor,
    required this.price,
    required this.description,
    required this.imageUrl,
    this.isExpanded = false,
    required this.orderOriginNo,
    required this.address,
    required this.recipient,
    required this.orderItems,
    this.outerPurchaseId,
    required this.productAllPrice,
    required this.currency,
    this.shopName,
    this.orderState = '',
    this.payStatus = '',
    this.feeSea = 0.0,
  });
}

// 订单项数据模型
class OrderItem {
  String name;
  String color;
  int quantity;
  String price;
  String imageUrl;

  OrderItem({
    required this.name,
    required this.color,
    required this.quantity,
    required this.price,
    required this.imageUrl,
  });
}
