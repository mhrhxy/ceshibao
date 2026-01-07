import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'dingbudaohang.dart';
import 'utils/http_util.dart';
import 'config/service_url.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'after_sales_application.dart';
import 'order_review.dart';

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
                      Text(
                        card.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      card.url.isNotEmpty
                          ? Image.network(
                            '$baseUrl${card.url}',
                            width: 100,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  width: 100,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                ),
                          )
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
      {
        'name':
            AppLocalizations.of(context)?.translate('payment_ended') ?? '付款结束',
        'count': 0,
        'orderState': 2,
        'orderPayState': 3,
      },
      {
        'name':
            AppLocalizations.of(context)?.translate('warehouse_in_ended') ??
            '入库结束',
        'count': 0,
        'orderState': 5,
        'orderPayState': 0,
      },
      {
        'name':
            AppLocalizations.of(context)?.translate('warehouse_out_pending') ??
            '出库待发',
        'count': 0,
        'orderState': 6,
        'orderPayState': 0,
      },
      {
        'name':
            AppLocalizations.of(context)?.translate('shipped_complete') ??
            '发货完成',
        'count': 0,
        'orderState': 7,
        'orderPayState': 0,
      },
      {
        'name':
            AppLocalizations.of(context)?.translate('cancel_order') ?? '取消订单',
        'count': 0,
        'orderState': -1,
        'orderPayState': 0,
      },
    ];
  }

  // 根据订单状态获取显示文字和颜色
  Map<String, dynamic> getOrderStatusInfo(String orderState, String payStatus) {
    String statusText =
        AppLocalizations.of(context)?.translate('unknown_status') ?? '未知状态';
    Color statusColor = Colors.grey;

    switch (orderState) {
      case '0':
        statusText =
            AppLocalizations.of(
              context,
            )?.translate('waiting_for_taobao_order') ??
            '待淘宝生成订单';
        statusColor = const Color.fromARGB(255, 137, 255, 147);
        break;
      case '1':
        statusText =
            AppLocalizations.of(context)?.translate('pending_payment') ?? '待支付';
        statusColor = Colors.orange;
        break;
      case '2':
        statusText = AppLocalizations.of(context)?.translate('paid') ?? '已支付';
        statusColor = Colors.green;
        break;
      case '3':
        statusText =
            AppLocalizations.of(context)?.translate('pending_shipment') ??
            '待发货';
        statusColor = Colors.blue;
        break;
      case '4':
        statusText =
            AppLocalizations.of(context)?.translate('shipping') ?? '发货中';
        statusColor = Colors.blueAccent;
        break;
      case '5':
        statusText =
            AppLocalizations.of(context)?.translate('warehouse_in') ?? '已入库';
        statusColor = Colors.purple;
        break;
      case '6':
        statusText =
            AppLocalizations.of(context)?.translate('warehouse_out_pending') ??
            '出库待发';
        statusColor = Colors.purpleAccent;
        break;
      case '7':
        statusText =
            AppLocalizations.of(context)?.translate('shipped_complete') ??
            '发货完成';
        statusColor = Colors.indigo;
        break;
      case '8':
        statusText =
            AppLocalizations.of(context)?.translate('arrived') ?? '已到货';
        statusColor = Colors.teal;
        break;
      case '9':
        statusText =
            AppLocalizations.of(context)?.translate('completed') ?? '已完成';
        statusColor = Colors.greenAccent;
        break;
      case '-1':
        statusText =
            AppLocalizations.of(context)?.translate('cancelled') ?? '已取消';
        statusColor = Colors.red;
        break;
      case '-2':
        statusText =
            AppLocalizations.of(context)?.translate('order_exception') ??
            '订单异常';
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
      return '¥$price';
    } else {
      return '₩$price';
    }
  }

  // 加载订单列表
  Future<void> loadOrderList(
    int orderState,
    int orderPayState,
    bool isRefresh,
  ) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // 获取韩元汇率
      double krwRate = await _fetchKrwRate();

      Map<String, dynamic> params = {
        'orderState': orderState,
        'orderPayState': orderPayState,
      };

      var response = await HttpUtil.get(
        searchOrderListUrl,
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        print('API返回数据: $data');
        if (data['code'] == 200) {
          List<OrderData> newOrders = [];

          for (var item in data['data']) {
            print('处理订单项: $item');
            // 获取总订单信息
            var orderAllInfo = item['orderAllInfo'];
            if (orderAllInfo == null) {
              print('orderAllInfo为null');
              continue;
            }
            // 获取子订单列表 - 使用正确的orderInfoList作为键名
            var orderInfoList = item['orderInfoList'] ?? [];
            print(
              'orderInfoList长度: ${orderInfoList.length}, 内容: $orderInfoList',
            );
            print('orderInfoList类型: ${orderInfoList.runtimeType}');
            print('处理子订单列表前，orderInfoList内容详情:');
            for (int i = 0; i < orderInfoList.length; i++) {
              print(
                '子订单$i: ${orderInfoList[i]}, orderId: ${orderInfoList[i]['orderId']}, shopName: ${orderInfoList[i]['shopName']}',
              );
            }

            // 获取订单状态信息
            var statusInfo = getOrderStatusInfo(
              orderAllInfo['orderState'],
              orderAllInfo['payStatus'],
            );

            // 将orderInfoList转换为shopOrders列表
            List<ShopOrderData> shopOrders = [];
            try {
              // 显式创建ShopOrderData列表，避免类型转换问题
              for (var shopItem in orderInfoList) {
                print(
                  '正在处理shopItem: $shopItem, orderId: ${shopItem['orderId']}, shopName: ${shopItem['shopName']}',
                );
                ShopOrderData shopOrder = ShopOrderData(
                  id: shopItem['orderId'].toString(),
                  shopName: shopItem['shopName'] ?? '未知店铺',
                  orderItems: [], // 后续从loadOrderProducts加载
                  isExpanded: false,
                  orderOriginNo: shopItem['orderOriginNo']?.toString() ?? '',
                  picture: shopItem['picture']?.toString() ?? '', // 获取订单图片
                  productAllPrice:
                      (shopItem['productAllPrice'] ?? 0.0), // 获取订单总价并转换为韩元
                  num: shopItem['num'] ?? 0, // 获取商品数量
                  observeIs: shopItem['observeIs']?.toString() ?? '1', // 获取评价状态
                  orderState:
                      shopItem['orderState']?.toString() ?? '', // 获取订单状态
                  payStatus: shopItem['payStatus']?.toString() ?? '', // 获取支付状态
                  refundStatus:
                      int.tryParse(
                        shopItem['refundStatus']?.toString() ?? '0',
                      ) ??
                      0, // 获取退款状态
                  remainingNum: shopItem['remainingNum'] ?? 0, // 获取剩余可退数量
                  refundId: shopItem['refundId']?.toString(), // 获取退款ID
                );
                shopOrders.add(shopOrder);
              }
              print('转换后的shopOrders长度: ${shopOrders.length}');
              for (int i = 0; i < shopOrders.length; i++) {
                print(
                  '转换后的子订单$i: id=${shopOrders[i].id}, shopName=${shopOrders[i].shopName}',
                );
              }
            } catch (e) {
              print('转换shopOrders失败: $e');
            }

            // 创建订单数据对象
            try {
              OrderData order = OrderData(
                id: orderAllInfo['orderAllId']?.toString() ?? '',
                title: '', // 初始为空，后续从orderItems中获取
                count: orderAllInfo['num'] ?? 1,
                status: statusInfo['text'],
                statusColor: statusInfo['color'],
                price: formatPrice(
                  (orderAllInfo['productAllPrice'] ?? 0),
                  'KRW',
                ),
                description: '',
                imageUrl: '', // 初始为空，后续从orderItems中获取
                isExpanded: false,
                orderOriginNo: orderAllInfo['orderOriginNo']?.toString() ?? '',
                address: '${orderAllInfo['address'] ?? ''}',
                recipient:
                    '${orderAllInfo['receiveName'] ?? ''} ${orderAllInfo['mobilePhone'] ?? ''}',
                orderItems: [],
                outerPurchaseId: orderAllInfo['outerPurchaseId'],
                productAllPrice: (orderAllInfo['productAllPrice'] ?? 0),
                currency: 'KRW',
                shopName:
                    shopOrders.isNotEmpty
                        ? shopOrders[0].shopName
                        : '', // 使用第一个店铺名称作为订单名称
                orderState: orderAllInfo['orderState']?.toString() ?? '',
                payStatus: orderAllInfo['payStatus']?.toString() ?? '',
                feeSea: orderAllInfo['feeSea'] ?? 0.0,
                refundStatus:
                    int.tryParse(
                      orderAllInfo['refundStatus']?.toString() ?? '0',
                    ) ??
                    0,
                remainingNum: orderAllInfo['remainingNum'] ?? 0,
                refundId: orderAllInfo['refundId']?.toString(),
                observeIs:
                    orderInfoList.isNotEmpty
                        ? orderInfoList[0]['observeIs']?.toString() ?? '1'
                        : '1', // 使用第一个子订单的评论状态
                shopOrders: shopOrders, // 子店铺订单列表
                orderPlateformNo: orderAllInfo['orderPlateformNo']?.toString() ?? '',
                picture: orderAllInfo['picture'] ?? '', // 使用orderAllInfo中的图片
              );

              newOrders.add(order);
              // 移除立即加载，改为点击下拉时调用
            } catch (e) {
              print('创建OrderData失败: $e');
            }
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
    } catch (e, stackTrace) {
      print('加载订单列表失败: $e');
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
        } else if (orderState ==
                (AppLocalizations.of(context)?.translate('cancelled') ??
                    '已取消') &&
            status['name'] ==
                (AppLocalizations.of(context)?.translate('cancel_order') ??
                    '取消订单')) {
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
      // 修复URL格式，确保没有重复的问号
      String apiUrl = searchOrderProductListUrl.replaceAll('?', '');
      Map<String, dynamic> params = {'orderIds': orderId};
      var response = await HttpUtil.get(apiUrl, queryParameters: params);

      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        if (data['code'] == 200) {
          List<OrderItem> orderItems = [];

          // 添加空值检查，避免当data['data']为null时出现类型错误
          var orderDataList = data['data'] ?? [];
          for (var item in orderDataList) {
            // 新接口结构，商品详情在orderProductInfo中
            var orderProductInfo = item['orderProductInfo'] ?? {};

            // 解析规格信息
            String specsText = '';
            if (orderProductInfo['sku'] != null &&
                orderProductInfo['sku'].toString().isNotEmpty) {
              try {
                var secJson = json.decode(orderProductInfo['sku']);
                if (secJson['properties'] != null &&
                    secJson['properties'] is List) {
                  List properties = secJson['properties'];
                  if (properties.isNotEmpty) {
                    specsText = properties
                        .map((p) => p['value_name'])
                        .where((v) => v != null && v.toString().isNotEmpty)
                        .join(' ');
                  }
                }
              } catch (e) {
                // 如果解析失败，回退到使用sku字段
                specsText = orderProductInfo['sku'] ?? '';
              }
            } else {
              // 如果没有sku字段
              specsText = orderProductInfo['sku'] ?? '';
            }

            OrderItem orderItem = OrderItem(
              name:
                  orderProductInfo['titleCn'] ??
                  orderProductInfo['titleEn'] ??
                  AppLocalizations.of(context)?.translate('product') ??
                  '商品',
              color: specsText,
              quantity: orderProductInfo['quantity'] ?? 1,
              price: formatPrice(
                (item['estimateAmountKRW'] ?? 0),
                'KRW',
              ), // 使用新字段priceKRW作为显示价格
              imageUrl:
                  orderProductInfo['imgUrl']?.replaceAll(' ', '') ??
                  'https://img.alicdn.com/bao/uploaded/i4/2214969080592/O1CN01chogkv1GFBG0iYKFj_!!2214969080592.png',
            );

            orderItems.add(orderItem);
          }

          // 更新对应订单的商品列表
          setState(() {
            for (var order in orderList) {
              // 查找包含当前子订单ID的主订单
              bool hasMatchingShopOrder = order.shopOrders.any(
                (shopOrder) => shopOrder.id == orderId,
              );
              if (hasMatchingShopOrder) {
                // 如果有shopOrders，将商品分配到对应的shopOrders中
                if (order.shopOrders.isNotEmpty) {
                  // 为每个shopOrder创建一个商品列表
                  Map<String, List<OrderItem>> shopOrderItemsMap = {};
                  for (var shopOrder in order.shopOrders) {
                    shopOrderItemsMap[shopOrder.id] = [];
                    print('创建子订单映射: ${shopOrder.id}(${shopOrder.shopName})');
                  }
                  print('shopOrderItemsMap的键: ${shopOrderItemsMap.keys}');

                  // 将商品分配到对应的shopOrders中
                  for (var item in orderDataList) {
                    // 从orderProductInfo中获取orderId作为子订单ID
                    var itemOrderId =
                        item['orderProductInfo']['orderId']?.toString() ?? '';
                    var orderProductInfo = item['orderProductInfo'] ?? {};

                    // 解析规格信息
                    String specsText = '';
                    if (orderProductInfo['sku'] != null &&
                        orderProductInfo['sku'].toString().isNotEmpty) {
                      try {
                        var secJson = json.decode(orderProductInfo['sku']);
                        if (secJson['properties'] != null &&
                            secJson['properties'] is List) {
                          List properties = secJson['properties'];
                          if (properties.isNotEmpty) {
                            specsText = properties
                                .map((p) => p['value_name'])
                                .where(
                                  (v) => v != null && v.toString().isNotEmpty,
                                )
                                .join(' ');
                          }
                        }
                      } catch (e) {
                        // 如果解析失败，回退到使用sku字段
                        specsText = orderProductInfo['sku'] ?? '';
                      }
                    }

                    OrderItem orderItem = OrderItem(
                      name:
                          orderProductInfo['titleCn'] ??
                          orderProductInfo['titleEn'] ??
                          AppLocalizations.of(context)?.translate('product') ??
                          '商品',
                      color: specsText,
                      quantity: orderProductInfo['quantity'] ?? 1,
                      price: formatPrice(
                        (item['estimateAmountKRW'] ?? 0),
                        'KRW',
                      ), // 使用新字段priceKRW作为显示价格
                      imageUrl:
                          orderProductInfo['imgUrl']?.replaceAll(' ', '') ??
                          'https://img.alicdn.com/bao/uploaded/i4/2214969080592/O1CN01chogkv1GFBG0iYKFj_!!2214969080592.png',
                    );

                    // 将商品添加到对应的shopOrder中
                    if (shopOrderItemsMap.containsKey(itemOrderId)) {
                      shopOrderItemsMap[itemOrderId]?.add(orderItem);
                      print('成功添加商品到子订单$itemOrderId');
                    } else {
                      // 如果找不到对应的子订单ID，将商品添加到当前请求的子订单中
                      if (shopOrderItemsMap.containsKey(orderId)) {
                        shopOrderItemsMap[orderId]?.add(orderItem);
                        print('无法匹配商品到子订单$itemOrderId，将商品添加到当前请求的子订单$orderId');
                      } else {
                        print(
                          '无法匹配商品到任何子订单: itemOrderId=$itemOrderId，当前请求的子订单ID=$orderId',
                        );
                      }
                    }
                  }

                  // 更新每个shopOrder的商品列表
                  List<ShopOrderData> newShopOrders = [];
                  for (var shopOrder in order.shopOrders) {
                    // 创建一个新的ShopOrderData对象来更新商品列表
                    // 如果当前展开的是这个子订单，确保保持展开状态
                    ShopOrderData updatedShopOrder = ShopOrderData(
                      id: shopOrder.id,
                      shopName: shopOrder.shopName,
                      orderItems: shopOrderItemsMap[shopOrder.id] ?? [],
                      isExpanded:
                          shopOrder.id == orderId ? true : shopOrder.isExpanded,
                      orderOriginNo: shopOrder.orderOriginNo,
                      picture: shopOrder.picture,
                      productAllPrice: shopOrder.productAllPrice,
                      num: shopOrder.num,
                      observeIs: shopOrder.observeIs,
                      orderState: shopOrder.orderState,
                      payStatus: shopOrder.payStatus,
                      refundStatus: shopOrder.refundStatus,
                      remainingNum: shopOrder.remainingNum,
                    );
                    newShopOrders.add(updatedShopOrder);
                    print(
                      '子订单${updatedShopOrder.id}(${updatedShopOrder.shopName})的商品数量: ${updatedShopOrder.orderItems.length}',
                    );
                  }

                  // 更新order.shopOrders
                  order.shopOrders = newShopOrders;

                  // 更新orderList以确保UI刷新
                  orderList = List.from(orderList);

                  // 更新主订单的orderItems列表（用于向后兼容）
                  order.orderItems = orderItems;
                } else {
                  // 如果没有shopOrders，使用原来的方式
                  order.orderItems = orderItems;
                }

                // 更新订单的标题和图片
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
      print(
        '${AppLocalizations.of(context)?.translate('load_order_items_failed') ?? '加载订单商品失败'}: $e',
      );
    }
  }

  // 切换订单项的展开/折叠状态
  void toggleExpand(String orderId) {
    setState(() {
      for (var order in orderList) {
        if (order.id == orderId) {
          order.isExpanded = !order.isExpanded;

          // 当只有一个子订单时，点击展开需要加载商品数据
          if (order.isExpanded && order.shopOrders.length == 1) {
            var shopOrder = order.shopOrders[0];
            // 如果子订单的商品列表为空，加载商品数据
            if (shopOrder.orderItems.isEmpty) {
              print('准备加载子订单${shopOrder.id}的商品数据');
              loadOrderProducts(shopOrder.id);
            }
          }
        }
      }
    });
  }

  void _cancelOrder(String orderId) async {
    try {
      // 获取订单对象以获取父订单ID
      final order = orderList.firstWhere((o) => o.id == orderId);

      // 构建新的请求体格式
      Map<String, dynamic> requestBody = {
        "orderIds": [], // 默认传空数组
        "orderAllId": [order.id], // 传父订单ID（OrderData的id字段就是orderAllId）
      };

      // 调用取消订单接口（使用PUT请求，将订单ID放在URL中，请求体放在data参数中）
      var response = await HttpUtil.put(cancelOrderUrl, data: requestBody);

      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        if (data['code'] == 200) {
          // 接口调用成功，更新本地状态
          setState(() {
            // 找到要取消的订单并更新状态
            final order = orderList.firstWhere((o) => o.id == orderId);
            order.status =
                AppLocalizations.of(context)?.translate('cancelled') ??
                '已取消'; // 更新状态为已取消
          });

          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                      context,
                    )?.translate('order_already_cancelled') ??
                    '订单已取消',
              ),
            ),
          );

          // 重新加载订单列表以获取最新状态
          onRefresh();
        } else {
          // 接口返回错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)?.translate('cancel_failed') ?? '取消失败'}: ${data['message'] ?? (AppLocalizations.of(context)?.translate('unknown_error') ?? '未知错误')}',
              ),
            ),
          );
        }
      } else {
        // 网络请求失败
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('network_request_failed') ??
                  '网络请求失败，请稍后重试',
            ),
          ),
        );
      }
    } catch (e) {
      // 捕获异常
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取消订单失败，请稍后重试')));
    }
  }

  // 取消退款的方法
  void _cancelRefund(dynamic order) async {
    try {
      // 根据订单类型获取退款ID和退款状态
      String? refundId;

      if (order is OrderData) {
        refundId = order.refundId;
      } else if (order is ShopOrderData) {
        refundId = order.refundId;
      }

      if (refundId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('cancel_failed') ??
                  '取消失败',
            ),
          ),
        );
        return;
      }

      // 调用取消退款接口
      String url = cancelRefundUrl.replaceFirst('{refundId}', refundId);
      var response = await HttpUtil.put(url);

      if (response.statusCode == 200) {
        var data = json.decode(response.toString());
        if (data['code'] == 200) {
          // 接口调用成功，更新本地状态
          setState(() {
            // 更新退款状态
            if (order is OrderData) {
              order.refundStatus = 0; // 假设0表示退款已取消
            } else if (order is ShopOrderData) {
              order.refundStatus = 0; // 假设0表示退款已取消
            }
          });

          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)?.translate('refund_cancelled') ??
                    '退款已取消',
              ),
            ),
          );

          // 重新加载订单列表以获取最新状态
          onRefresh();
        } else {
          // 接口返回错误信息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)?.translate('cancel_failed') ?? '取消失败'}: ${data['message'] ?? (AppLocalizations.of(context)?.translate('unknown_error') ?? '未知错误')}',
              ),
            ),
          );
        }
      } else {
        // 网络请求失败
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('network_request_failed') ??
                  '网络请求失败，请稍后重试',
            ),
          ),
        );
      }
    } catch (e) {
      // 捕获异常
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取消退款失败，请稍后重试')));
    }
  }

  // 立即支付的方法
  // 使用选定的支付卡处理支付
  // NaverPay支付方法
  Future<void> _processPaymentWithNaverpay(
    String orderId, {
    double? customAmount,
    bool isOverseasShipping = false,
  }) async {
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

      // 查询美元和韩元汇率
      dynamic usdRate = 0.14; // 默认美元汇率，防止接口调用失败
      dynamic koreanWonRate = 14700; // 默认韩元汇率，防止接口调用失败
      dynamic rmbzmy = 14700; //人民币转美元
      try {
        // 查询美元汇率
        var usdRateResponse = await HttpUtil.get(
          searchRateUrl,
          queryParameters: {
            'currency': 3, // 美元 转换后汇率类型（1.人民币 2.韩元 3.美元）
            'type': 1,
            'benchmarkCurrency': 2, // 人民币 转会前汇率类型（1.人民币 2.韩元 3.美元）
          },
        );

        if (usdRateResponse.statusCode == 200 &&
            usdRateResponse.data['code'] == 200) {
          usdRate = usdRateResponse.data['data'];
        }
        print('美元汇率查询成功: $usdRate');

        // 查询韩元汇率
        var krwRateResponse = await HttpUtil.get(
          searchRateUrl,
          queryParameters: {
            'currency': 2, // 韩元 转换后汇率类型（1.人民币 2.韩元 3.美元）
            'type': 1,
            'benchmarkCurrency': 1, // 人民币 转会前汇率类型（1.人民币 2.韩元 3.美元）
          },
        );

        if (krwRateResponse.statusCode == 200 &&
            krwRateResponse.data['code'] == 200) {
          koreanWonRate = krwRateResponse.data['data'];
        }
        print('韩元汇率查询成功: $koreanWonRate');

        // 查询韩元汇率
        var RmbRateResponse = await HttpUtil.get(
          searchRateUrl,
          queryParameters: {
            'currency': 3, // 人民币  转换后汇率类型（1.人民币 2.韩元 3.美元）
            'type': 1,
            'benchmarkCurrency': 1, //美元 转会前汇率类型（1.人民币 2.韩元 3.美元）
          },
        );

        if (RmbRateResponse.statusCode == 200 &&
            RmbRateResponse.data['code'] == 200) {
          rmbzmy = RmbRateResponse.data['data'];
        }
        print('韩元汇率查询成功: $rmbzmy');
      } catch (e) {
        print('查询汇率失败: $e');
      }

      // 计算美元金额
      // ignore: unnecessary_type_check
      double amount =
          customAmount ??
          (orderData.productAllPrice is double
              ? orderData.productAllPrice
              : double.tryParse(orderData.productAllPrice.toString()) ?? 0.0);
      double usdAmount;
      if (customAmount != null && isOverseasShipping) {
        // 如果是海外运费支付，需要将人民币转换为美元：人民币 * 美元汇率
        usdAmount = double.parse((amount * rmbzmy).toStringAsFixed(2));
      } else {
        // 如果是订单总金额（已经是韩元），需要先转换为人民币，再转换为美元
        // 或者是立即支付的订单金额（已经是韩元），也需要先转换为人民币，再转换为美元
        usdAmount = double.parse((amount / usdRate).toStringAsFixed(2));
      }

      // 构建请求参数，使用实际订单数据
      Map<String, dynamic> requestData = {
        "payCommon": {
          "orderAllId": int.tryParse(orderData.id), // 订单ID
          "type": 1, // 支付类型，NaverPay默认传1
          "payCost": usdAmount.toString(), // 支付金额（转换为美元，保留两位小数）
          "orderNo": orderData.orderPlateformNo, // 订单编号
          "paymentRedirectUrl":
              "flutterappxm://pay/callback?orderNo=${orderData.orderPlateformNo}",
        },
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
          await launchUrl(
            Uri.parse(redirectUrl),
            mode: LaunchMode.externalApplication,
          );

          // 支付后返回应用，显示中性提示并刷新订单列表以检查实际支付状态
          Future.delayed(const Duration(seconds: 1), () {
            // 检查Widget是否仍然存在
            if (mounted) {
              // 显示提示信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                          context,
                        )?.translate('check_order_status_for_payment_result') ??
                        '请查看订单状态确认支付结果',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );

              // 重新加载订单数据以获取最新支付状态
              onRefresh();
            }
          });
        } else {
          throw Exception('无法打开支付页面');
        }
      } else {
        throw Exception(
          AppLocalizations.of(context)?.translate('payment_failed') ?? '支付失败',
        );
      }
    } catch (e) {
      print('NaverPay支付失败: $e');
      // 显示支付失败提示
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                AppLocalizations.of(context)?.translate('payment_failed') ??
                    '支付失败',
              ),
              content: Text(
                AppLocalizations.of(
                      context,
                    )?.translate('please_wait_patiently') ??
                    '请耐心等待',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)?.translate('confirm') ?? '确定',
                  ),
                ),
              ],
            ),
      );
    }
  }

  // 卡支付方法
  Future<void> _processPaymentWithCard(
    String orderId,
    int payCardId, {
    double? customAmount,
    bool isOverseasShipping = false,
  }) async {
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
        var rateResponse = await HttpUtil.get(
          searchRateUrl,
          queryParameters: {
            'currency': 2, // 韩元
            'type': 1,
            'benchmarkCurrency': 1, // 人民币
          },
        );

        if (rateResponse.statusCode == 200 &&
            rateResponse.data['code'] == 200) {
          koreanWonRate = rateResponse.data['data'];
        }
        print('韩元汇率查询成功: $koreanWonRate');
      } catch (e) {
        print('查询汇率失败: $e');
      }

      // 计算韩元金额
      // ignore: unnecessary_type_check
      double totalAmount =
          customAmount ??
          (orderData.productAllPrice is double
              ? orderData.productAllPrice
              : double.tryParse(orderData.productAllPrice.toString()) ?? 0.0);
      // 如果是海外运费支付，需要将人民币转换为韩元；否则已经是韩元
      double krwAmount;
      if (customAmount != null && isOverseasShipping) {
        // 人民币 * 韩元汇率 = 韩元，保留两位小数
        krwAmount = double.parse(
          (totalAmount).toStringAsFixed(2),
        );
      } else {
        // 金额已经是韩元，直接保留两位小数
        krwAmount = double.parse(totalAmount.toStringAsFixed(2));
      }

      // 构建请求参数，使用实际订单数据
      Map<String, dynamic> requestData = {
        "payCommon": {
          "orderAllId": int.tryParse(orderData.id), // 订单ID
          "type": 2, // 支付类型，卡支付默认传2
          "payCost": krwAmount.toString(), // 支付金额（韩元，保留两位小数）
          "orderNo": orderData.orderPlateformNo, // 订单编号
          "paymentRedirectUrl":
              "flutterappxm://pay/callback?orderNo=${orderData.orderPlateformNo}",
        },
        "cardBrand": "KAKAOBANK", // 卡银行
        "isCardNormal": 1, // 是否通用银行卡
      };
      // print('支付请求参数: $requestData');

      // 调用卡支付接口
      // print('调用卡支付接口，订单ID: $orderId, 支付卡ID: $payCardId');
      var response = await HttpUtil.post(cardpay, data: requestData);

      // 处理接口返回
      if (response.data['code'] == 200 && response.data['data'] != null) {
        String redirectUrl = response.data['data']['redirectUrl'];
        String paymentRequestId = response.data['data']['paymentRequestId'];

        // print('支付跳转URL: $redirectUrl');
        // print('支付请求ID: $paymentRequestId');

        // 使用url_launcher跳转到第三方支付页面
        if (await canLaunchUrl(Uri.parse(redirectUrl))) {
          await launchUrl(
            Uri.parse(redirectUrl),
            mode: LaunchMode.externalApplication,
          );

          // 支付完成后，提示用户已返回应用并刷新订单列表
          Future.delayed(const Duration(seconds: 3), () {
            // 检查Widget是否仍然存在
            if (mounted) {
              // 显示提示信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(
                          context,
                        )?.translate('payment_completed') ??
                        '支付已完成',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );

              // 重新加载订单数据
              onRefresh();
            }
          });
        } else {
          throw Exception('无法打开支付页面');
        }
      } else {
        throw Exception('支付失败');
      }
    } catch (e) {
      // 显示支付失败提示
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                AppLocalizations.of(context)?.translate('payment_failed') ??
                    '支付失败',
              ),
              content: Text(
                AppLocalizations.of(
                      context,
                    )?.translate('please_wait_patiently') ??
                    '请耐心等待',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context)?.translate('confirm') ?? '确定',
                  ),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _showCardSelectionModal(
    BuildContext context,
    String orderId, {
    double? customAmount,
    bool isOverseasShipping = false,
  }) async {
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
                    Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('select_payment_card') ??
                          '选择支付卡',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                      return Center(
                        child: Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('get_payment_cards_failed') ??
                              '获取支付卡失败',
                        ),
                      );
                    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return _buildCardList(snapshot.data!);
                    } else {
                      return Center(
                        child: Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('no_available_payment_cards') ??
                              '暂无可用支付卡',
                        ),
                      );
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
                      // 可以调用支付接口
                      _processPaymentWithCard(
                        orderId,
                        _selectedCardId!,
                        customAmount: customAmount,
                        isOverseasShipping: isOverseasShipping,
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.translate('confirm') ?? '确认',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 获取韩元转人民币汇率
  Future<double> _fetchKrwRate() async {
    try {
      var rateResponse = await HttpUtil.get(
        searchRateUrl,
        queryParameters: {
          'currency': 2, // 韩元
          'type': 1,
          'benchmarkCurrency': 1, // 人民币
        },
      );

      if (rateResponse.statusCode == 200 && rateResponse.data['code'] == 200) {
        double rate =
            rateResponse.data['data'] is double
                ? rateResponse.data['data']
                : double.tryParse(rateResponse.data['data'].toString()) ?? 0.0;
        // 如果汇率为0或获取失败，返回1.0确保价格显示正常
        return rate > 0 ? rate : 1.0;
      }
    } catch (e) {
      print('查询韩元汇率失败: $e');
    }
    // 默认返回1.0，确保价格计算不会为0
    return 1.0;
  }

  // 支付运费的方法
  void _payShippingFee(String orderId, double shippingFee) async {
    // 显示支付方式弹窗
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)?.translate('select_payment_method') ??
                '选择支付方式',
          ),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<List<PaymentMethod>>(
              future: _fetchPaymentMethods(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('get_payment_methods_failed') ??
                          '获取支付方式失败',
                    ),
                  );
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
                                _showCardSelectionModal(
                                  context,
                                  orderId,
                                  customAmount: shippingFee,
                                  isOverseasShipping: true,
                                );
                              } else if (payment.name == 'Naver支付') {
                                Navigator.of(context).pop();
                                _processPaymentWithNaverpay(
                                  orderId,
                                  customAmount: shippingFee,
                                  isOverseasShipping: true,
                                );
                              }
                            },
                            child: Column(
                              children: [
                                Text(
                                  payment.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),
                                payment.url.isNotEmpty
                                    ? Image.network(
                                      payment.url,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    )
                                    : Container(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Center(
                    child: Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('no_available_payment_methods') ??
                          '暂无可用支付方式',
                    ),
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context)?.translate('disabled') ?? '关闭',
              ),
            ),
          ],
        );
      },
    );
  }

  void _payOrder(String orderId) async {
    // 根据orderId查找对应的订单数据
    OrderData? orderData;
    try {
      orderData = orderList.firstWhere((order) => order.id == orderId);
    } catch (e) {
      orderData = null;
    }

    // 如果找不到订单数据，显示错误提示
    if (orderData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('order_info_not_found') ??
                '找不到对应订单信息',
          ),
        ),
      );
      return;
    }

    // 提前获取支付方式列表，避免在setState时重复执行异步请求
    List<PaymentMethod> paymentMethods = [];
    bool isLoadingPayment = true;
    String? paymentError;
    try {
      paymentMethods = await _fetchPaymentMethods();
    } catch (e) {
      paymentError =
          AppLocalizations.of(
            context,
          )?.translate('get_payment_methods_failed') ??
          '获取支付方式失败';
    } finally {
      isLoadingPayment = false;
    }

    // 显示支付方式弹窗
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 使用StatefulBuilder创建局部状态管理
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                AppLocalizations.of(
                      context,
                    )?.translate('select_payment_method') ??
                    '결제수단',
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 支付方式部分 - 水平排列的正方形选择框
                    isLoadingPayment
                        ? Center(child: CircularProgressIndicator())
                        : paymentError != null
                        ? Center(child: Text(paymentError))
                        : paymentMethods.isNotEmpty
                        ? Container(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: paymentMethods.length,
                            itemBuilder: (context, index) {
                              final payment = paymentMethods[index];
                              return Container(
                                width: 100,
                                height: 100,
                                margin: EdgeInsets.only(right: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    // 根据支付方式类型调用不同的支付方法
                                    if (payment.name == '卡支付') {
                                      Navigator.of(context).pop();
                                      // 等待支付操作完成
                                      await _showCardSelectionModal(
                                        context,
                                        orderId,
                                      );
                                      // 支付完成后刷新订单列表
                                      if (mounted) {
                                        onRefresh();
                                      }
                                    } else if (payment.name == 'Naver支付') {
                                      Navigator.of(context).pop();
                                      // 等待支付操作完成
                                      await _processPaymentWithNaverpay(
                                        orderId,
                                      );
                                      // 支付完成后刷新订单列表
                                      if (mounted) {
                                        onRefresh();
                                      }
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      payment.url.isNotEmpty
                                          ? Image.network(
                                            payment.url,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => Container(
                                                  width: 40,
                                                  height: 40,
                                                  color: Colors.grey[200],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          )
                                          : Container(),
                                      SizedBox(height: 8),
                                      Text(
                                        payment.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                        : Center(
                          child: Text(
                            AppLocalizations.of(
                                  context,
                                )?.translate('no_available_payment_methods') ??
                                '暂无可用支付方式',
                          ),
                        ),
                  ],
                ),
              ),
            );
          },
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

  // 去评价
  void _goToReview(dynamic order) {
    // 跳转到评价页面
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderReviewPage(order: order)),
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
                  AppLocalizations.of(context)?.translate('my_orders') ??
                      "我的订单",
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
                            AppLocalizations.of(
                                  context,
                                )?.translate('all_orders') ??
                                '全部订单',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  currentStatusIndex == -1
                                      ? Colors.blue
                                      : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            totalOrderCount.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                            ),
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
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    currentStatusIndex == index
                                        ? Colors.blue
                                        : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              status['count'].toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.zero, // 去掉圆角
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.translate('all_orders_kr') ??
                        '모든주문',
                    style: TextStyle(fontSize: 12),
                  ),
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
                        Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('direct_purchase') ??
                              '直购',
                          style: const TextStyle(fontSize: 12),
                        ),
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
                        Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('recommended') ??
                              '推荐',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 订单列表
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : orderList.isEmpty
                    ? Center(
                      child: Text(
                        AppLocalizations.of(
                              context,
                            )?.translate('no_order_data') ??
                            '暂无订单数据',
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.builder(
                        itemCount: orderList.length,
                        itemBuilder: (context, index) {
                          final order = orderList[index];
                          return Container(
                            margin: const EdgeInsets.only(top: 10),
                            color: const Color.fromRGBO(
                              249,
                              250,
                              251,
                              1,
                            ), // #F9FAFB
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // 根据子订单数量显示不同的图标或图片
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              order.shopOrders.length == 1
                                                  ? (order.shopOrders[0].picture.isNotEmpty
                                                      ? order.picture
                                                      : order.picture)
                                                  : order.picture,
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Icon(
                                                  order.shopOrders.length == 1
                                                      ? Icons.store
                                                      : Icons.shopping_cart_checkout,
                                                  size: 36,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // 商品信息
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // 根据子订单数量显示不同的标题
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // 标题文本：只有一个子订单时显示店铺名称，否则显示订单号
                                                  Flexible(
                                                    fit: FlexFit.loose,
                                                    child: Text(
                                                      order.shopOrders.length ==
                                                              1
                                                          ? order
                                                              .shopOrders[0]
                                                              .shopName
                                                          : '订单号: ${order.orderOriginNo}',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: 4,
                                                  ), // 添加小间距使布局更协调
                                                  // 蓝色圆形数量标签 - 显示商品数量
                                                  Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.blue,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      order.shopOrders.length ==
                                                              1
                                                          ? '${order.shopOrders[0].num}'
                                                          : '${order.count}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              // 价格 - 只有一个子订单时显示子订单价格，否则显示总订单价格
                                              Text(
                                                order.shopOrders.length == 1
                                                    ? formatPrice(
                                                      order
                                                          .shopOrders[0]
                                                          .productAllPrice,
                                                      'KRW',
                                                    )
                                                    : order.price,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              // 根据子订单数量显示不同的文本
                                              if (order.shopOrders.length > 1)
                                                // 多个子订单时，显示店铺数量
                                                Text(
                                                  '共${order.shopOrders.length}家店铺',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // 右侧状态、按钮和箭头的水平布局
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // 蓝框内的垂直布局：订单状态和取消订单按钮（居中对齐）
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                // 显示订单状态文本
                                                Text(
                                                  order.status,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: getStatusTextColor(order.status),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // 取消退款按钮（只有退款状态为1时显示，且只有当子订单数量为1时，才在总订单处显示）
                                                order.refundStatus == 1 &&
                                                        order
                                                                .shopOrders
                                                                .length ==
                                                            1
                                                    ? Column(
                                                      children: [
                                                        TextButton(
                                                          onPressed: () {
                                                            // 取消退款的逻辑
                                                            _cancelRefund(
                                                              order
                                                                  .shopOrders[0],
                                                            );
                                                          },
                                                          style: TextButton.styleFrom(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                                  context,
                                                                )?.translate(
                                                                  'cancel_refund',
                                                                ) ??
                                                                '取消退款',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                      ],
                                                    )
                                                    : Container(),
                                                // 取消订单按钮和立即支付按钮（只有待支付状态显示）
                                                if (order.status ==
                                                    (AppLocalizations.of(
                                                          context,
                                                        )?.translate(
                                                          'pending_payment',
                                                        ) ??
                                                        '待支付'))
                                                  Column(
                                                    children: [
                                                      TextButton(
                                                        onPressed: () {
                                                          // 取消订单的逻辑
                                                          _cancelOrder(
                                                            order.id,
                                                          );
                                                        },
                                                        style: TextButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          AppLocalizations.of(
                                                                context,
                                                              )?.translate(
                                                                'cancel_order',
                                                              ) ??
                                                              '取消订单',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // 立即支付按钮（只有待支付状态显示）
                                                      TextButton(
                                                        onPressed: () {
                                                          // 立即支付的逻辑
                                                          _payOrder(order.id);
                                                        },
                                                        style: TextButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          AppLocalizations.of(
                                                                context,
                                                              )?.translate(
                                                                'pay_now',
                                                              ) ??
                                                              '立即支付',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                // 运费支付按钮（只有orderState等于5并且payStatus等于3时显示）
                                                if (order.orderState == '5' &&
                                                    order.payStatus == '3')
                                                  Column(
                                                    children: [
                                                      const SizedBox(height: 4),
                                                      TextButton(
                                                        onPressed: () {
                                                          // 运费支付的逻辑
                                                          _payShippingFee(
                                                            order.id,
                                                            order.feeSea,
                                                          );
                                                        },
                                                        style: TextButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          AppLocalizations.of(
                                                                context,
                                                              )?.translate(
                                                                'pay_shipping_fee',
                                                              ) ??
                                                              '支付运费',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                // 申请售后按钮显示逻辑：
                                                // 1. 先判断refundStatus是否是1，如果是的话，说明在申请中，不显示申请售后按钮
                                                // 2. 根据orderState和payStatus区分退款类型：
                                                //    - orderState为2且payStatus为3：只允许仅退款/部分仅退款
                                                //    - orderState为3：只能仅退款/部分仅退款
                                                //    - orderState为4/5/6：仅退款、退货退款/仅部分退款/仅部分退货退款都能选择
                                                // 3. remainingNum大于0时显示
                                                // 4. 只有当子订单数量为1时，才在总订单处显示申请售后按钮
                                                if (order.refundStatus != 1 &&
                                                    order.remainingNum > 0 &&
                                                    order.shopOrders.length == 1 &&
                                                    ((order.orderState == '2' && order.payStatus == '3') ||
                                                     (order.orderState == '3') ||
                                                     (order.orderState == '4' || order.orderState == '5' || order.orderState == '6')))
                                                  Column(
                                                    children: [
                                                      const SizedBox(height: 4),
                                                      TextButton(
                                                        onPressed: () {
                                                          // 申请售后的逻辑
                                                          // 当只有一个子订单时，传递子订单的ID
                                                          _applyAfterSales(
                                                            order.shopOrders[0],
                                                          );
                                                        },
                                                        style: TextButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          AppLocalizations.of(
                                                                context,
                                                              )?.translate(
                                                                'apply_after_sales',
                                                              ) ??
                                                              '申请售后',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                // 去评价按钮显示逻辑：orderState为9并且observeIs为1时显示
                                                // 只有当子订单数量为1时，才在总订单处显示评价按钮
                                                if (order.orderState == '9' &&
                                                    order.observeIs == '1' &&
                                                    order.shopOrders.length ==
                                                        1)
                                                  Column(
                                                    children: [
                                                      const SizedBox(height: 4),
                                                      TextButton(
                                                        onPressed: () {
                                                          // 去评价的逻辑
                                                          // 当只有一个子订单时，传递子订单的ID
                                                          _goToReview(
                                                            order.shopOrders[0],
                                                          );
                                                        },
                                                        style: TextButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          AppLocalizations.of(
                                                                context,
                                                              )?.translate(
                                                                'go_to_review',
                                                              ) ??
                                                              '去评价',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(width: 4),
                                            // 展开/收起箭头 - 保持不变
                                            Icon(
                                              order.isExpanded
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
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
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 配送地址 - 添加灰色背景和圆角
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(
                                            bottom: 15,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                      context,
                                                    )?.translate(
                                                      'shipping_address',
                                                    ) ??
                                                    '配送地址',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                order.address,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                '${AppLocalizations.of(context)?.translate('recipient') ?? '收件人'}: ${order.recipient}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 订单商品列表
                                        // 如果有子订单（shopOrders），直接显示子订单信息，不依赖orderItems
                                        Column(
                                          children: [
                                            // 当shopOrders不为空时，按店铺分组显示
                                            if (order.shopOrders.isNotEmpty)
                                              ...order.shopOrders
                                                  .map(
                                                    (shopOrder) => Column(
                                                      key: ValueKey(
                                                        shopOrder.id,
                                                      ),
                                                      children: [
                                                        // 只有当有多个子订单时，才显示店铺头部
                                                        if (order
                                                                .shopOrders
                                                                .length >
                                                            1)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  bottom: 12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors
                                                                      .grey[50],
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  // 创建一个新的列表，更新所有子订单的展开状态
                                                                  List<
                                                                    ShopOrderData
                                                                  >
                                                                  newShopOrders =
                                                                      [];
                                                                  for (var eachShopOrder
                                                                      in order
                                                                          .shopOrders) {
                                                                    // 如果是当前点击的子订单，切换其展开状态
                                                                    if (eachShopOrder
                                                                            .id ==
                                                                        shopOrder
                                                                            .id) {
                                                                      bool
                                                                      newExpandedState =
                                                                          !eachShopOrder
                                                                              .isExpanded;
                                                                      ShopOrderData
                                                                      updatedShopOrder = ShopOrderData(
                                                                        id:
                                                                            eachShopOrder.id,
                                                                        shopName:
                                                                            eachShopOrder.shopName,
                                                                        orderItems:
                                                                            eachShopOrder.orderItems,
                                                                        isExpanded:
                                                                            newExpandedState,
                                                                        orderOriginNo:
                                                                            eachShopOrder.orderOriginNo,
                                                                        picture:
                                                                            eachShopOrder.picture,
                                                                        productAllPrice:
                                                                            eachShopOrder.productAllPrice,
                                                                        num:
                                                                            eachShopOrder.num,
                                                                        observeIs:
                                                                            eachShopOrder.observeIs,
                                                                        orderState:
                                                                            eachShopOrder.orderState,
                                                                        payStatus:
                                                                            eachShopOrder.payStatus,
                                                                        refundStatus:
                                                                            eachShopOrder.refundStatus,
                                                                        remainingNum:
                                                                            eachShopOrder.remainingNum,
                                                                      );
                                                                      newShopOrders
                                                                          .add(
                                                                            updatedShopOrder,
                                                                          );
                                                                      print(
                                                                        '切换子订单${updatedShopOrder.id}的展开状态为: ${updatedShopOrder.isExpanded}',
                                                                      );

                                                                      // 如果是展开状态且商品列表为空，加载商品数据
                                                                      if (newExpandedState &&
                                                                          updatedShopOrder
                                                                              .orderItems
                                                                              .isEmpty) {
                                                                        print(
                                                                          '准备加载子订单${updatedShopOrder.id}的商品数据',
                                                                        );
                                                                        loadOrderProducts(
                                                                          updatedShopOrder
                                                                              .id,
                                                                        );
                                                                      }
                                                                    } else {
                                                                      // 其他子订单全部收起
                                                                      ShopOrderData
                                                                      updatedShopOrder = ShopOrderData(
                                                                        id:
                                                                            eachShopOrder.id,
                                                                        shopName:
                                                                            eachShopOrder.shopName,
                                                                        orderItems:
                                                                            eachShopOrder.orderItems,
                                                                        isExpanded:
                                                                            false,
                                                                        orderOriginNo:
                                                                            eachShopOrder.orderOriginNo,
                                                                        picture:
                                                                            eachShopOrder.picture,
                                                                        productAllPrice:
                                                                            eachShopOrder.productAllPrice,
                                                                        num:
                                                                            eachShopOrder.num,
                                                                        observeIs:
                                                                            eachShopOrder.observeIs,
                                                                        orderState:
                                                                            eachShopOrder.orderState,
                                                                        payStatus:
                                                                            eachShopOrder.payStatus,
                                                                        refundStatus:
                                                                            eachShopOrder.refundStatus,
                                                                        remainingNum:
                                                                            eachShopOrder.remainingNum,
                                                                      );
                                                                      newShopOrders
                                                                          .add(
                                                                            updatedShopOrder,
                                                                          );
                                                                    }
                                                                  }
                                                                  // 更新订单的shopOrders列表
                                                                  order.shopOrders =
                                                                      newShopOrders;
                                                                });
                                                              },
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      // 店铺图片
                                                                      shopOrder
                                                                              .picture
                                                                              .isNotEmpty
                                                                          ? Image.network(
                                                                            shopOrder.picture,
                                                                            width:
                                                                                40,
                                                                            height:
                                                                                40,
                                                                            fit:
                                                                                BoxFit.cover,
                                                                            errorBuilder: (
                                                                              context,
                                                                              error,
                                                                              stackTrace,
                                                                            ) {
                                                                              return const Icon(
                                                                                Icons.storefront,
                                                                                size:
                                                                                    40,
                                                                                color:
                                                                                    Colors.grey,
                                                                              );
                                                                            },
                                                                          )
                                                                          : const Icon(
                                                                            Icons.storefront,
                                                                            size:
                                                                                40,
                                                                            color:
                                                                                Colors.grey,
                                                                          ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            shopOrder.shopName,
                                                                            style: const TextStyle(
                                                                              fontSize:
                                                                                  16,
                                                                              fontWeight:
                                                                                  FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            '共${shopOrder.num}件商品',
                                                                            style: TextStyle(
                                                                              fontSize:
                                                                                  14,
                                                                              color:
                                                                                  Colors.grey[600],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      // 价格和评价按钮垂直排列
                                                                      Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          // 订单总价
                                                                          Text(
                                                                            formatPrice(
                                                                              shopOrder.productAllPrice,
                                                                              'KRW',
                                                                            ),
                                                                            style: const TextStyle(
                                                                              fontSize:
                                                                                  16,
                                                                              fontWeight:
                                                                                  FontWeight.w600,
                                                                              color:
                                                                                  Colors.red,
                                                                            ),
                                                                          ),
                                                                          // 去评价按钮：当有多个子订单时显示在价格下方
                                                                          if (shopOrder.orderState ==
                                                                                  '9' &&
                                                                              shopOrder.observeIs ==
                                                                                  '1' &&
                                                                              order.shopOrders.length >
                                                                                  1)
                                                                            Padding(
                                                                              padding: const EdgeInsets.only(
                                                                                top:
                                                                                    5,
                                                                              ), // 调整垂直间距
                                                                              child: TextButton(
                                                                                onPressed: () {
                                                                                  // 创建一个临时OrderData对象，只包含当前子订单的信息

                                                                                  _goToReview(
                                                                                    shopOrder,
                                                                                  );
                                                                                },
                                                                                style: TextButton.styleFrom(
                                                                                  padding: const EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                        8,
                                                                                    vertical:
                                                                                        2,
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  AppLocalizations.of(
                                                                                        context,
                                                                                      )?.translate(
                                                                                        'go_to_review',
                                                                                      ) ??
                                                                                      '去评价',
                                                                                  style: TextStyle(
                                                                                    fontSize:
                                                                                        12,
                                                                                    color:
                                                                                        Colors.blue,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          // 申请售后按钮：当有多个子订单时显示在价格下方
                                                                          // 新规则：先判断refundStatus是否为1（申请中不显示），再根据orderStatus和payStatus区分退款类型
                                                                          if (shopOrder.refundStatus != 1 &&
                                                                              shopOrder.remainingNum > 0 &&
                                                                              order.shopOrders.length > 1 &&
                                                                              (
                                                                                // orderStatus 2 且 payStatus 3：仅退款/部分仅退款
                                                                                (shopOrder.orderState == '2' && shopOrder.payStatus == '3') ||
                                                                                // orderStatus 3：仅退款/部分仅退款
                                                                                (shopOrder.orderState == '3') ||
                                                                                // orderStatus 4\5\6：所有退款类型
                                                                                (shopOrder.orderState == '4' || shopOrder.orderState == '5' || shopOrder.orderState == '6')
                                                                              ))
                                                                            Padding(
                                                                              padding: const EdgeInsets.only(
                                                                                top:
                                                                                    5,
                                                                              ), // 调整垂直间距
                                                                              child: TextButton(
                                                                                onPressed: () {
                                                                                  // 申请售后的逻辑，传递当前子订单
                                                                                  _applyAfterSales(
                                                                                    shopOrder,
                                                                                  );
                                                                                },
                                                                                style: TextButton.styleFrom(
                                                                                  padding: const EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                        8,
                                                                                    vertical:
                                                                                        2,
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  AppLocalizations.of(
                                                                                        context,
                                                                                      )?.translate(
                                                                                        'apply_after_sales',
                                                                                      ) ??
                                                                                      '申请售后',
                                                                                  style: TextStyle(
                                                                                    fontSize:
                                                                                        12,
                                                                                    color:
                                                                                        Colors.blue,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          // 取消退款按钮：当有多个子订单且退款状态为1时显示在价格下方
                                                                          if (shopOrder.refundStatus ==
                                                                                  1 &&
                                                                              order.shopOrders.length >
                                                                                  1)
                                                                            Padding(
                                                                              padding: const EdgeInsets.only(
                                                                                top:
                                                                                    5,
                                                                              ), // 调整垂直间距
                                                                              child: TextButton(
                                                                                onPressed: () {
                                                                                  // 取消退款的逻辑，传递当前子订单
                                                                                  _cancelRefund(
                                                                                    shopOrder,
                                                                                  );
                                                                                },
                                                                                style: TextButton.styleFrom(
                                                                                  padding: const EdgeInsets.symmetric(
                                                                                    horizontal:
                                                                                        8,
                                                                                    vertical:
                                                                                        2,
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  AppLocalizations.of(
                                                                                        context,
                                                                                      )?.translate(
                                                                                        'cancel_refund',
                                                                                      ) ??
                                                                                      '取消退款',
                                                                                  style: TextStyle(
                                                                                    fontSize:
                                                                                        12,
                                                                                    color:
                                                                                        Colors.red,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                        ],
                                                                      ),
                                                                      SizedBox(
                                                                        width:
                                                                            10,
                                                                      ), // 添加右侧间距
                                                                      Icon(
                                                                        shopOrder.isExpanded
                                                                            ? Icons.expand_less
                                                                            : Icons.expand_more,
                                                                        color:
                                                                            Colors.grey[600],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        // 店铺商品列表
                                                        // 只有一个子订单时，直接显示商品信息；多个子订单时，需要点击展开
                                                        if (order
                                                                    .shopOrders
                                                                    .length ==
                                                                1 ||
                                                            shopOrder
                                                                .isExpanded)
                                                          Column(
                                                            children:
                                                                shopOrder
                                                                    .orderItems
                                                                    .map(
                                                                      (
                                                                        item,
                                                                      ) => Container(
                                                                        margin: const EdgeInsets.only(
                                                                          bottom:
                                                                              12,
                                                                        ),
                                                                        padding:
                                                                            const EdgeInsets.all(
                                                                              12,
                                                                            ),
                                                                        decoration: BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(
                                                                                8,
                                                                              ),
                                                                          border: Border.all(
                                                                            color:
                                                                                Colors.grey[100]!,
                                                                          ),
                                                                        ),
                                                                        child: Row(
                                                                          children: [
                                                                            // 商品图片
                                                                            Image.network(
                                                                              item.imageUrl,
                                                                              width:
                                                                                  60,
                                                                              height:
                                                                                  60,
                                                                              fit:
                                                                                  BoxFit.cover,
                                                                              errorBuilder:
                                                                                  (
                                                                                    _,
                                                                                    __,
                                                                                    ___,
                                                                                  ) => Container(
                                                                                    width:
                                                                                        60,
                                                                                    height:
                                                                                        60,
                                                                                    color:
                                                                                        Colors.grey[200],
                                                                                    child: const Icon(
                                                                                      Icons.image_not_supported,
                                                                                      color:
                                                                                          Colors.grey,
                                                                                    ),
                                                                                  ),
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  12,
                                                                            ),
                                                                            // 商品信息
                                                                            Expanded(
                                                                              child: Column(
                                                                                crossAxisAlignment:
                                                                                    CrossAxisAlignment.start,
                                                                                mainAxisAlignment:
                                                                                    MainAxisAlignment.spaceBetween,
                                                                                children: [
                                                                                  Text(
                                                                                    item.name,
                                                                                    style: const TextStyle(
                                                                                      fontSize:
                                                                                          16,
                                                                                      color:
                                                                                          Colors.black87,
                                                                                    ),
                                                                                    maxLines:
                                                                                        1,
                                                                                    overflow:
                                                                                        TextOverflow.ellipsis,
                                                                                  ),
                                                                                  Text(
                                                                                    item.color.isNotEmpty
                                                                                        ? item.color
                                                                                        : (AppLocalizations.of(
                                                                                              context,
                                                                                            )?.translate(
                                                                                              'no_specification',
                                                                                            ) ??
                                                                                            '无规格'),
                                                                                    style: TextStyle(
                                                                                      fontSize:
                                                                                          14,
                                                                                      color:
                                                                                          Colors.grey[600],
                                                                                    ),
                                                                                  ),
                                                                                  Row(
                                                                                    mainAxisAlignment:
                                                                                        MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                      Text(
                                                                                        item.price,
                                                                                        style: const TextStyle(
                                                                                          fontSize:
                                                                                              18,
                                                                                          color:
                                                                                              Colors.red,
                                                                                          fontWeight:
                                                                                              FontWeight.w500,
                                                                                        ),
                                                                                      ),
                                                                                      Text(
                                                                                        'x${item.quantity}',
                                                                                        style: TextStyle(
                                                                                          fontSize:
                                                                                              15,
                                                                                          color:
                                                                                              Colors.grey[600],
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    )
                                                                    .toList(),
                                                          ),
                                                      ],
                                                    ),
                                                  )
                                                  .toList(),
                                            // 当shopOrders为空时，保持原有显示逻辑
                                            if (order.shopOrders.isEmpty)
                                              ...order.orderItems
                                                  .map(
                                                    (item) => Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            bottom: 12,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              Colors.grey[100]!,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          // 商品图片
                                                          Image.network(
                                                            item.imageUrl,
                                                            width: 60,
                                                            height: 60,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  _,
                                                                  __,
                                                                  ___,
                                                                ) => Container(
                                                                  width: 60,
                                                                  height: 60,
                                                                  color:
                                                                      Colors
                                                                          .grey[200],
                                                                  child: const Icon(
                                                                    Icons
                                                                        .image_not_supported,
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                  ),
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          // 商品信息
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Text(
                                                                  item.name,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    color:
                                                                        Colors
                                                                            .black87,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                Text(
                                                                  item
                                                                          .color
                                                                          .isNotEmpty
                                                                      ? item
                                                                          .color
                                                                      : (AppLocalizations.of(
                                                                            context,
                                                                          )?.translate(
                                                                            'no_specification',
                                                                          ) ??
                                                                          '无规格'),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color:
                                                                        Colors
                                                                            .grey[600],
                                                                  ),
                                                                ),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      item.price,
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            18,
                                                                        color:
                                                                            Colors.red,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      'x${item.quantity}',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            15,
                                                                        color:
                                                                            Colors.grey[600],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          ],
                                        ),
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
        ],
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
  int refundStatus; // 退款状态 1. 申请退款 2. 淘宝退款 -1. 退款失败 3. 淘宝退款完成 4. 退款完成
  int remainingNum; // 剩余可退款数量
  String? refundId; // 退款ID
  String observeIs; // 是否可以评价 1:可以评价 2:评价过了不能评价
  List<ShopOrderData> shopOrders; // 子店铺订单列表
  String orderPlateformNo; // 订单平台编号
  String picture; // 订单图片

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
    this.refundStatus = 0,
    this.remainingNum = 0,
    this.refundId,
    this.observeIs = '1', // 默认可以评价
    this.shopOrders = const [], // 默认空列表，确保向后兼容
    this.orderPlateformNo = '', // 默认平台订单编号为空
    this.picture = '', // 默认订单图片为空
  });
}

// 子店铺订单数据模型
class ShopOrderData {
  String id;
  String shopName;
  List<OrderItem> orderItems;
  bool isExpanded;
  String orderOriginNo;
  String picture; // 订单图片
  double productAllPrice; // 订单总价
  int num; // 商品数量
  String observeIs; // 是否可以评价 1:可以评价 2:评价过了不能评价
  String orderState; // 订单状态编号
  String payStatus; // 支付状态编号
  int refundStatus; // 退款状态 1. 申请退款 2. 淘宝退款 -1. 退款失败 3. 淘宝退款完成 4. 退款完成
  int remainingNum; // 剩余可退数量
  String? refundId; // 退款ID

  ShopOrderData({
    required this.id,
    required this.shopName,
    required this.orderItems,
    this.isExpanded = false,
    required this.orderOriginNo,
    this.picture = '',
    this.productAllPrice = 0.0,
    this.num = 0,
    this.observeIs = '', // 默认可以评价
    this.orderState = '', // 默认订单状态为空
    this.payStatus = '', // 默认支付状态为空
    this.refundStatus = 0, // 默认退款状态为0
    this.remainingNum = 0, // 默认剩余可退数量为0
    this.refundId,
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
