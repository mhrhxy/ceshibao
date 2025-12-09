import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dingbudaohang.dart';
import 'package:daum_postcode_view/daum_postcode_view.dart';
import 'app_localizations.dart';
import 'config/service_url.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'Myorder.dart';
import './utils/http_util.dart';
import 'package:url_launcher/url_launcher.dart';



class PaymentPage extends StatefulWidget {
  final List<Map<String, dynamic>>? selectedProducts;

  const PaymentPage({super.key, this.selectedProducts});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _showAddressModal = false; // 控制地址弹窗的显示
  int? _selectedAddressIndex = 0; // 默认选中第一个地址
  String _zipcode = ''; // 邮编
  String _address = ''; // 地址
  String _detailAddress = ''; // 详细地址
  
  // 表单字段
  String _name = ''; // 姓名
  String _phone = ''; // 手机号
  String _customsCode = ''; // 个人通关号码
  String _deliveryNotes = ''; // 配送邀请事项
  
  // 订单创建状态
  bool _isCreatingOrder = false; // 创建订单中状态
  
  // 地址数据 - 从API获取
  List<Map<String, dynamic>> _addressList = [];
  bool _isLoadingAddress = false; // 地址加载状态
  String? _addressErrorMsg; // 地址加载错误信息
  
  @override
  void initState() {
    super.initState();
    // 打印接收到的商品数据
  }
  
  // 从API获取地址列表
  Future<void> _fetchAddressList() async {
    setState(() {
      _isLoadingAddress = true;
      _addressErrorMsg = null;
    });

    try {
      final response = await HttpUtil.get(
        uaddresslist,
        queryParameters: {"pageNum": 1, "pageSize": 20}, // 获取前20条地址
      );

      if (response.data['code'] == 200) {
        List<dynamic> dataList = response.data['rows'] ?? [];
        // 格式化地址数据以匹配现有的UI格式
        List<Map<String, dynamic>> formattedAddressList = dataList.map((item) {
          // 构建完整地址字符串：国家 + 省 + 市 + 区 + 详细地址
          String fullAddress = '${item['country'] ?? ''} ${item['state'] ?? ''} ${item['city'] ?? ''} ${item['district'] ?? ''} ${item['addressDetail'] ?? ''}'.trim();
          
          return {
            'id': item['userAddressId'], // 使用真实的地址ID
            'address': fullAddress, // 完整地址
            'receiver': '${item['name'] ?? ''} ${item['tel'] ?? ''}', // 收件人姓名和电话
            'isDefault': item['defaultAddress'] == '2', // 根据接口文档，2表示默认地址
            'original': item // 保留原始数据，以便后续使用
          };
        }).toList();

        setState(() {
          _addressList = formattedAddressList;
          // 如果有地址且未选中任何地址，则默认选中第一个地址
          if (_addressList.isNotEmpty && _selectedAddressIndex == null) {
            _selectedAddressIndex = 0;
          }
          _isLoadingAddress = false;
        });
      } else {
        throw Exception(response.data['msg'] ?? '获取地址列表失败');
      }
    } catch (e) {
      setState(() {
        _addressErrorMsg = e.toString();
        _isLoadingAddress = false;
      });
      developer.log('地址列表接口请求失败: $e');
    }
  }
  
  // 从widget获取选中的商品数据
  List<Map<String, dynamic>> get selectedProducts => widget.selectedProducts ?? [];
  
  // 计算商品统计信息
  Map<String, dynamic> _calculateProductStats() {
    final List<Map<String, dynamic>> products = _prepareProductsData();
    
    // 计算商品种类数量（去重后的商品数量）
    Set<String> uniqueProducts = Set();
    int totalQuantity = 0;
    double totalPrice = 0.0;
    double totalTaobaoFee = 0.0;
    
    for (var product in products) {
      // 使用商品名称和描述作为唯一标识
      String productKey = '${product['name']}-${product['description']}';
      uniqueProducts.add(productKey);
      
      // 计算总数量和总价
      int quantity = product['quantity'] ?? 1;
      double price = (product['price'] ?? 0).toDouble();
      
      totalQuantity += quantity;
      totalPrice += price * quantity;
      
      // 累加每个商品的淘宝运费
      double productTaobaoFee = (product['taobaofee'] ?? 0.0).toDouble();
      totalTaobaoFee += productTaobaoFee;
    }
    
    // 将运费加到总价上
    totalPrice += totalTaobaoFee;
    
    print('计算的商品总价: $totalPrice, 总运费: $totalTaobaoFee');
    
    return {
      'categoryCount': uniqueProducts.length,
      'totalQuantity': totalQuantity,
      'totalPrice': totalPrice
    };
  }
  
  // 准备商品数据，将购物车数据转换为Payment页面需要的格式
  List<Map<String, dynamic>> _prepareProductsData() {
    print('准备处理的商品数据: $selectedProducts');
    print('原始商品数据是否为空: ${selectedProducts.isEmpty}');

    
    List<Map<String, dynamic>> result = [];
    print('开始处理店铺数据，共有${selectedProducts.length}个店铺');
    
    
    // 处理购物车数据结构
    for (var shopData in selectedProducts) {
      String shopName = shopData['shopName'] ?? '未知店铺';
      List<dynamic> cartList = shopData['cartList'] ?? [];
      
      for (var item in cartList) {
        // 从secName字段中解析颜色信息
        String color = '默认颜色';
        try {
          if (item['secName'] != null) {
            String secName = item['secName'];
            if (secName.contains('颜色分类:')) {
              color = secName.split('颜色分类:')[1]?.trim() ?? color;
            } else {
              color = secName;
            }
          }
        } catch (e) {
          // 解析失败时使用默认值
        }
        
        result.add({
          'shopName': shopName,
          'image': item['productUrl']?.replaceAll('`', '')?.trim() ?? 'https://picsum.photos/100/100',
          'name': item['productNameCn'] ?? item['productName'] ?? '商品名称',
          'description': item['secName'] ?? '商品描述',
          'color': color,
          'quantity': item['num'] ?? 1,
          'price': item['productPrice'] ?? 0,
          'taobaofee': item['taobaofee'] ?? 0.0, // 添加淘宝运费字段
          // 保留原始字段信息
          'cartId': item['cartId'],
          'productId': item['productId'],
          'shopId': item['shopId'],
          'productName': item['productName'],
          'productNameEn': item['productNameEn'],
          'productNameCn': item['productNameCn'],
          'secName': item['secName'],
          'sec': item['sec'],
          'productUrl': item['productUrl'],
          'selfSupport': () {
            dynamic value = item['selfSupport'];
            if (value == null) return 1;
            if (value is int) return value;
            if (value is String) {
              try {
                return int.parse(value);
              } catch (e) {
                return 1; // 解析失败时使用默认值
              }
            }
            return 1; // 其他类型时使用默认值
          }()
        });
      }
    }
    
    return result;
  }
  
  // 按店铺分组商品
  Map<String, List<Map<String, dynamic>>> _groupProductsByShop(List<Map<String, dynamic>> products) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var product in products) {
      String shopName = product['shopName'] ?? '未知店铺';
      if (!grouped.containsKey(shopName)) {
        grouped[shopName] = [];
      }
      grouped[shopName]!.add(product);
    }
    
    return grouped;
  }
  
  // 构建单个商品项
  Widget _buildProductItem(Map<String, dynamic> product) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          // 商品图片
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(
                image: NetworkImage(product['image']),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 10),
          // 商品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  product['description'],
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${product['price']?.toString() ?? '0'}元',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color.fromARGB(255, 3, 209, 54)),
                    ),
                    Text(
                      'x${product['quantity'] ?? 1}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  

  Widget _buildOrderItems(BuildContext context) {
    // 根据选中的商品数据构建订单商品列表
    final List<Map<String, dynamic>> products = _prepareProductsData();

    // 按店铺分组显示商品
    final Map<String, List<Map<String, dynamic>>> productsByShop = _groupProductsByShop(products);
    
    return Column(
      children: productsByShop.entries.map((shopEntry) {
        String shopName = shopEntry.key;
        List<Map<String, dynamic>> shopProducts = shopEntry.value;
        
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.store_outlined, size: 16),
                  SizedBox(width: 5),
                  Text(shopName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 10),
              // 渲染该店铺的所有商品
              ...shopProducts.map((product) => _buildProductItem(product)).toList()
            ]
          ),
        );
      }).toList(),
    );
  }


  Widget _buildDeliveryInfo(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)?.translate('shipping_info') ?? '配送信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ElevatedButton(
                    onPressed: () {
                      // 显示地址弹窗并获取地址列表
                      setState(() {
                        _showAddressModal = true;
                      });
                      // 调用API获取地址列表
                      _fetchAddressList();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(AppLocalizations.of(context)?.translate('get_address') ?? '调取地址', style:  TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
          const SizedBox(height: 15),
          
          // 配送信息表单
          Column(
            children: [
              _buildFormItem(context, 'name', AppLocalizations.of(context)?.translate('name') ?? '名字'),
              const SizedBox(height: 12),
              _buildFormItem(context, 'phone', AppLocalizations.of(context)?.translate('phone') ?? '电话'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFormItem(context, 'customs_code', AppLocalizations.of(context)?.translate('personal_customs_code') ?? '个人通关号码'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      // 打开外部浏览器访问海关个人通关码网址
                      const url = 'https://unipass.customs.go.kr/csp/persIndex.do';
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)?.translate('cannot_launch_url') ?? '无法打开网址')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(AppLocalizations.of(context)?.translate('query_issue') ?? '查询/签发', style:  TextStyle(fontSize: 12, color: Colors.black)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildFormItem(context, 'postal_code', AppLocalizations.of(context)?.translate('postal_code') ?? '邮编')),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _openDaumPostcode,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: Text(AppLocalizations.of(context)?.translate('search_postcode') ?? '搜索邮编', style:  TextStyle(fontSize: 12, color: Colors.black)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFormItem(context, 'detail_address', AppLocalizations.of(context)?.translate('detail_address') ?? '详细地址'),
              const SizedBox(height: 12),
              _buildFormItem(context, 'delivery_notes', AppLocalizations.of(context)?.translate('delivery_notes') ?? '配送邀请事项'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormItem(BuildContext context, String fieldName, String label) {
    String? value;
    bool readOnly = false;
    
    // 根据字段名设置初始值和只读状态
    if (fieldName == 'postal_code') {
      value = _zipcode;
    } else if (fieldName == 'address') {
      value = _address;
      readOnly = true; // 地址字段只读，通过搜索邮编填充
    } else if (fieldName == 'detail_address') {
      value = _detailAddress;
    } else if (fieldName == 'name') {
      value = _name;
    } else if (fieldName == 'phone') {
      value = _phone;
    } else if (fieldName == 'customs_code') {
      value = _customsCode;
    } else if (fieldName == 'delivery_notes') {
      value = _deliveryNotes;
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 20), // 添加标签和输入框之间的间距
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: '${AppLocalizations.of(context)?.translate('please_input') ?? '请输入'}$label',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            style: const TextStyle(fontSize: 14),
            readOnly: readOnly,
            onChanged: (text) {
              // 处理字段的输入变化
              if (fieldName != 'address') { // 地址字段只读，不需要处理变化
                setState(() {
                  switch (fieldName) {
                    case 'postal_code':
                      _zipcode = text;
                      break;
                    case 'detail_address':
                      _detailAddress = text;
                      break;
                    case 'name':
                      _name = text;
                      break;
                    case 'phone':
                      _phone = text;
                      break;
                    case 'customs_code':
                      _customsCode = text;
                      break;
                    case 'delivery_notes':
                      _deliveryNotes = text;
                      break;
                  }
                });
              }
            },
            // 使用初始值而不是controller，避免状态不同步
            controller: TextEditingController(text: value),
          ),
        ),
      ],
    );
  }

  // Widget _buildPaymentMethods(BuildContext context) {
  //   return Container(
  //     margin: const EdgeInsets.only(top: 10),
  //     padding: const EdgeInsets.all(15),
  //     color: Colors.white,
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(AppLocalizations.of(context)?.translate('payment_method') ?? '支付方式', style:  TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
  //         const SizedBox(height: 15),
          
  //         // 支付方式加载中状态
  //         if (_isLoadingPaymentMethods) 
  //           Center(child: CircularProgressIndicator()),
          
  //         // 支付方式加载错误状态
  //         if (!_isLoadingPaymentMethods && _paymentMethodsErrorMsg != null)
  //           Center(child: Text(_paymentMethodsErrorMsg!, style: TextStyle(color: Colors.red))),
          
  //         // 支付方式网格 - 使用从API获取的数据
  //         if (!_isLoadingPaymentMethods && _paymentMethods.isNotEmpty) 
  //           _buildPaymentMethodsGrid(context),
              
  //         // 默认支付方式（当API未返回数据时显示）
  //         if (!_isLoadingPaymentMethods && _paymentMethods.isEmpty && _paymentMethodsErrorMsg == null)
  //           GridView.count(
  //             shrinkWrap: true,
  //             physics: const NeverScrollableScrollPhysics(),
  //             crossAxisCount: 3,
  //             mainAxisSpacing: 10,
  //             crossAxisSpacing: 10,
  //             children: [
  //               _buildPaymentOption(context, 'paypal', AppLocalizations.of(context)?.translate('pay_option_1') ?? 'Pay', Colors.blue),
  //               _buildPaymentOption(context, 'toss', AppLocalizations.of(context)?.translate('pay_option_2') ?? 'Toss Pay', Colors.green),
  //               _buildPaymentOption(context, 'npay', AppLocalizations.of(context)?.translate('pay_option_3') ?? 'N Pay', Colors.blue),
  //             ],
  //           ),
  //       ],
  //     ),
  //   );
  // }
  
  // // 构建支付方式网格的辅助方法
  // Widget _buildPaymentMethodsGrid(BuildContext context) {
  //   // 添加调试日志
  //   developer.log('原始支付方式数据: $_paymentMethods');
    
  //   // 放宽过滤条件，只检查必要的字段是否存在
  //   final validPaymentMethods = _paymentMethods
  //     .where((method) => method['id'] != null && method['id'].toString().isNotEmpty && method['name'] != null && method['name'].toString().isNotEmpty)
  //     .toList();
    
  //   developer.log('过滤后的支付方式: $validPaymentMethods');
    
  //   if (validPaymentMethods.isNotEmpty) {
  //     return GridView.count(
  //       shrinkWrap: true,
  //       physics: const NeverScrollableScrollPhysics(),
  //       crossAxisCount: 3,
  //       mainAxisSpacing: 10,
  //       crossAxisSpacing: 10,
  //       children: validPaymentMethods
  //         .map((method) => _buildPaymentOptionWithLogo(
  //           context,
  //           method['id'].toString(),
  //           method['name'].toString(),
  //           method['logoUrl']?.toString() ?? '',
  //           payMethod: method['payMethod']?.toString() ?? ''
  //         ))
  //         .toList(),
  //     );
  //   } else {
  //     // 显示空状态提示
  //     return Center(
  //       child: Padding(
  //         padding: const EdgeInsets.all(20),
  //         child: Text(AppLocalizations.of(context)?.translate('no_payment_methods_available') ?? '暂无可用支付方式'),
  //       ),
  //     );
  //   }
  // }
  
// 简化的接口请求方法（只请求一次，返回卡片数据）
Future<List<Map<String, dynamic>>> _fetchPaymentCardsAsync() async {
  try {
    final response = await HttpUtil.get(cardlist);
    if (response.statusCode == 200 && response.data['code'] == 200) {
      List<dynamic> data = response.data['data'] ?? [];
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception(response.data['msg'] ?? '接口返回失败');
    }
  } catch (e) {
    throw Exception(e.toString());
  }
}


// 保留你原来的 _setSelectedPaymentMethod 方法（不变）
// void _setSelectedPaymentMethod(String paymentMethodId, Map<String, dynamic> selectedCard) {
//   setState(() {
//     _selectedPaymentMethod = paymentMethodId;
//     _selectedCardId = selectedCard['payCardId']?.toString(); // 设置选中的卡片ID
//   });
// }

//   // 确认卡片选择
//   void _confirmCardSelection() {
//     if (_selectedCardId != null && _currentPaymentMethodId != null) {
//       // 找到选中的卡片信息
//       final selectedCard = _paymentCards.firstWhere(
//         (card) => card['payCardId'].toString() == _selectedCardId,
//         orElse: () => {},
//       );
      
//       if (selectedCard.isNotEmpty) {
//         // 保存选中的支付方式和卡片信息
//         _setSelectedPaymentMethod(_currentPaymentMethodId!, selectedCard);
        

        
//         // 提示用户选择成功
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('已选择卡片: ${selectedCard['name'] ?? '未知卡片'}'),
//             duration: const Duration(seconds: 2),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//       }
      
//       // 重置状态
//       setState(() {
//         _isCardModalVisible = false;
//         _selectedCardId = null;
//         _currentPaymentMethodId = null;
//       });
//     }
//   }

// 点击卡支付时调用这个方法（入口）
// void _showCardModal(BuildContext context) {
//   // 1. 先显示加载弹窗（可选，提升体验，避免用户以为没反应）
//   showDialog(
//     context: context,
//     barrierDismissible: false, // 禁止点击空白关闭
//     builder: (ctx) => const Center(child: CircularProgressIndicator()),
//   );

//   // 2. 只调用一次接口（关键：接口请求在弹窗渲染前完成）
//   _fetchPaymentCardsAsync().then((cards) {
//     // 接口成功，关闭加载弹窗
//     Navigator.pop(context);

//     if (!mounted) return; // 页面已销毁就不继续

//     // 3. 弹窗内的选中状态（局部状态，只管弹窗内部，不影响外部）
//     String? selectedCardId;
//     // 默认选中第一个卡片（满足需求）
//     if (cards.isNotEmpty) {
//       selectedCardId = cards[0]['payCardId'].toString();
//     }

//     // 4. 显示真正的卡片选择弹窗（此时数据已就绪，不会再请求接口）
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return StatefulBuilder(
//           // 仅用 StatefulBuilder 管理弹窗内的选中状态（极简用法）
//           builder: (context, setStateModal) {
//             return Container(
//               padding: const EdgeInsets.all(20),
//               height: MediaQuery.of(context).size.height * 0.7,
//               child: Column(
//                 children: [
//                   // 标题栏
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text(
//                         '选择支付卡',
//                         style: TextStyle(fontSize: 18,),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.close),
//                         onPressed: () => Navigator.pop(context),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 20),

//                   // 卡片列表（直接渲染接口返回的数据，无重复请求）
//                   Expanded(
//                     child: cards.isEmpty
//                         ? const Center(child: Text('暂无可用卡片'))
//                         : ListView.builder(
//                             itemCount: cards.length,
//                             itemBuilder: (context, index) {
//                               final card = cards[index];
//                               final cardId = card['payCardId'].toString();
//                               final isSelected = selectedCardId == cardId;

//                               return Card(
//                                 margin: const EdgeInsets.symmetric(vertical: 8),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(10),
//                                   side: BorderSide(
//                                     color: isSelected ? Colors.green : Colors.transparent,
//                                     width: 2,
//                                   ),
//                                 ),
//                                 child: InkWell(
//                                   // 点击卡片切换选中状态（仅更新弹窗内局部状态）
//                                   onTap: () {
//                                     setStateModal(() {
//                                       selectedCardId = cardId;
//                                     });
//                                   },
//                                   child: Padding(
//                                     padding: const EdgeInsets.all(16),
//                                     child: Row(
//                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                       children: [
//                                         // 卡片logo + 名称
//                                         Row(
//                                           children: [
//                                             Container(
//                                               width: 40,
//                                               height: 40,
//                                               decoration: BoxDecoration(
//                                                 borderRadius: BorderRadius.circular(4),
//                                                 color: Colors.grey[200],
//                                                 image: card['url'] != null
//                                                     ? DecorationImage(
//                                                         image: NetworkImage('$baseUrl${card['url']}'),
//                                                         fit: BoxFit.cover,
//                                                       )
//                                                     : null,
//                                               ),
//                                             ),
//                                             const SizedBox(width: 16),
//                                             Text(card['name'] ?? '未知卡片'),
//                                           ],
//                                         ),
//                                         // 选中radio
//                                         Radio<String>(
//                                           value: cardId,
//                                           groupValue: selectedCardId,
//                                           onChanged: (value) {
//                                             setStateModal(() {
//                                               selectedCardId = value;
//                                             });
//                                           },
//                                           activeColor: Colors.green,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                   ),

//                   // 确认按钮
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 50),
//                       backgroundColor: selectedCardId != null ? Colors.green : Colors.grey[300],
//                     ),
//                     onPressed: selectedCardId == null
//                         ? null
//                         : () {
//                             // 找到选中的卡片
//                             final selectedCard = cards.firstWhere(
//                               (c) => c['payCardId'].toString() == selectedCardId,
//                               orElse: () => {},
//                             );
//                             if (selectedCard.isNotEmpty) {
//                               _setSelectedPaymentMethod(_currentPaymentMethodId!, selectedCard);
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(content: Text('已选择卡片: ${selectedCard['name'] ?? '未知卡片'}')),
//                               );
//                             }
//                             Navigator.pop(context);
//                             // 重置外部状态（可选）
//                             setState(() {
//                               _isCardModalVisible = false;
//                               _currentPaymentMethodId = null;
//                             });
//                           },
//                     child: const Text('确认', style: TextStyle(fontSize: 16, color: Colors.white)),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }).catchError((error) {
//     // 接口失败，关闭加载弹窗并提示
//     Navigator.pop(context);
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('获取卡片失败: $error')),
//       );
//     }
//   });
// }


//   // 使用LOGO的支付方式选项构建方法
//   Widget _buildPaymentOptionWithLogo(BuildContext context, String id, String name, String logoUrl, {String payMethod = ''}) {
//     final isSelected = _selectedPaymentMethod == id;
//     return GestureDetector(
//       onTap: () {
//           // 根据payMethod区分处理方式
//           if (payMethod == '2') {
//             // 卡支付，打开底部弹窗
//             developer.log('选择了卡支付方式: $name');
//             _currentPaymentMethodId = id; // 保存当前支付方式ID
//             _showCardModal(context); // 显示卡片选择弹窗
//           } else {
//             // Naver支付(1)或其他支付方式，直接选择
//             setState(() {
//               _selectedPaymentMethod = id;
//             });
//           }
//         },
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: isSelected ? Colors.green : Colors.grey,
//             width: isSelected ? 2 : 1,
//           ),
//           borderRadius: BorderRadius.circular(8),
//           color: Colors.white,
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // 支付方式LOGO
//             Container(
//               width: 40,
//               height: 40,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(4),
//                 image: DecorationImage(
//                   image: NetworkImage(logoUrl),
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 5),
//             Text(name, style: const TextStyle(fontSize: 12)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPaymentOption(BuildContext context, String id, String name, Color color) {
//     final isSelected = _selectedPaymentMethod == id;
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _selectedPaymentMethod = id;
//         });
//       },
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           border: Border.all(
//             color: isSelected ? Colors.green : Colors.grey,
//             width: isSelected ? 2 : 1,
//           ),
//           borderRadius: BorderRadius.circular(8),
//           color: Colors.white,
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.payment_outlined, size: 32, color: color),
//             const SizedBox(height: 5),
//             Text(name, style: const TextStyle(fontSize: 12)),
//           ],
//         ),
//       ),
//     );
//   }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const FixedActionTopBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 商品列表部分
                      _buildOrderItems(context),
                       
                      // 配送信息部分
                      _buildDeliveryInfo(context),

                       
                      // 优惠券/积分部分
                      _buildCouponPointsSection(context),
                    ],
                  ),
                ),
              ),
               
              // 底部结算栏
              _buildBottomBar(context),
            ],
          ),
          
          // 地址弹窗
          _showAddressModal ? _buildAddressModal(context) : Container(),
        ],
      ),
    );
  }

  Widget _buildCouponPointsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.centerLeft,
            child: Text(AppLocalizations.of(context)?.translate('my_points') ?? '我的积分', style:  TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 15),
          
          // 主要内容行 - 所有内容在同一行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 左侧：优惠券和积分标签，以及绿色按钮
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)?.translate('coupon') ?? '优惠券', style:  TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(AppLocalizations.of(context)?.translate('points') ?? '积分', style:  TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      // 全额使用按钮
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(AppLocalizations.of(context)?.translate('use_all') ?? '全额使用', style:  TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
              
              // 右侧：可用积分信息、输入框和全额显示
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 可用积分信息
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context)?.translate('available_points') ?? '可用积分', style:  TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(AppLocalizations.of(context)?.translate('points') ?? '个', style:  TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // 积分输入框和P单位
                  Row(
                    children: [
                      // 积分输入框（缩小高度）
                      SizedBox(
                        width: 80,
                        height: 28,
                        child: TextField(
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(AppLocalizations.of(context)?.translate('points_unit') ?? 'P', style:  TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 全额积分显示
                  Text('${AppLocalizations.of(context)?.translate('total') ?? '全额'}: 10,000${AppLocalizations.of(context)?.translate('points_unit') ?? 'P'}', style:  TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    // 计算商品统计信息
    final stats = _calculateProductStats();
    final categoryCount = stats['categoryCount'];
    final totalQuantity = stats['totalQuantity'];
    final totalPrice = stats['totalPrice'];
    
    // 格式化价格，添加千位分隔符
    String formattedPrice = '${totalPrice.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (Match m) => ',')}';
    
    return Container(
        padding: const EdgeInsets.all(15),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   Text('选中商品:${categoryCount}种类 总数量: ${totalQuantity}个', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    const SizedBox(height: 5),
                    Text('${AppLocalizations.of(context)?.locale.languageCode == 'zh' ? 'CNY' : 'KRW'} $formattedPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.green)),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isCreatingOrder ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(120, 45),
                  ),
                  child: _isCreatingOrder 
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2) 
                    : Text(AppLocalizations.of(context)?.translate('buy_now') ?? '立即购买', style:  TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
            // const SizedBox(height: 5),
            // Align(
            //     alignment: Alignment.centerLeft,
            //     child: Text(AppLocalizations.of(context)?.translate('shipping_fee') ?? '配送费', style:  TextStyle(fontSize: 12, color: Colors.red)),
            //   ),
          ],
        ),
      );
  }
  
  // 创建订单
  Future<void> _createOrder() async {
    // 表单验证
    if (_name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_input_name') ?? '请输入姓名')),
      );
      return;
    }
    
    if (_phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_input_phone') ?? '请输入手机号')),
      );
      return;
    }
    
    if (_zipcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_input_postal_code') ?? '请输入邮编')),
      );
      return;
    }
    
    if (_detailAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_input_detail_address') ?? '请输入详细地址')),
      );
      return;
    }
    
    setState(() {
      _isCreatingOrder = true;
    });
    
    try {

      // 准备商品数据
      final List<Map<String, dynamic>> products = _prepareProductsData();
      final Map<String, List<Map<String, dynamic>>> productsByShop = _groupProductsByShop(products);
      
      // 验证支付方式选择
      // if (_selectedPaymentMethod == null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_select_payment_method') ?? '请选择支付方式')),
      //   );
      //   setState(() {
      //     _isCreatingOrder = false;
      //   });
      //   return;
      // }
      
      // 构建订单请求体
      // 计算总金额和总数量
      double totalSumAmount = 0.0;
      int totalNum = 0;
      List<Map<String, dynamic>> orderInfoDTOList = [];
      
      productsByShop.forEach((shopName, shopProducts) {
        // 计算店铺商品总金额（不包含运费）
        double purchaseAmount = 0.0;
        double totalTaobaoFee = 0.0;
        List<Map<String, dynamic>> orderProductInfoList = [];
        String cartIds = '';
        int totalQuantity = 0;
        
        // 确定店铺商品的selfSupport值（所有商品应该具有相同的selfSupport值）
        int selfSupport = shopProducts.first['selfSupport'] ?? 1;
        
        for (var product in shopProducts) {
          int quantity = product['quantity'] ?? 1;
          double price = (product['price'] ?? 0).toDouble();
          double taobaoFee = (product['taobaofee'] ?? 0.0).toDouble();
          
          purchaseAmount += price * quantity;
          totalTaobaoFee += taobaoFee;
          totalQuantity += quantity;
          
          // 添加购物车ID（使用实际的cartId）
          if (cartIds.isNotEmpty) cartIds += ',';
          cartIds += '${product['cartId'] ?? product.hashCode}';
          
          // 构建订单商品信息
          orderProductInfoList.add({
            // 优先使用原始cartId，如果没有则使用哈希码作为备选
            'skuId': () {
              try {
                // 解析sec字符串为JSON对象并获取mpId
                if (product['sec'] != null && product['sec'] is String && product['sec'].isNotEmpty) {
                  final Map<String, dynamic> secJson = jsonDecode(product['sec']);
                  return secJson['spmpId'] ?? '';
                }
                return '';
              } catch (e) {
                return '';
              }
            }(),
            'quantity': quantity,
            'price': price,
            // 使用保留的原始字段信息
            'title': product['productName'] ?? product['name'], // 优先使用原始productName
            'titleEn': product['productNameEn'] ?? product['productName'] ?? product['name'],
            'titleCn': product['productNameCn'] ?? product['productName'] ?? product['name'],
            'itemId': () {
              try {
                // 解析sec字符串为JSON对象并获取mpId
                if (product['sec'] != null && product['sec'] is String && product['sec'].isNotEmpty) {
                  final Map<String, dynamic> secJson = jsonDecode(product['sec']);
                  return secJson['mpId'] ?? '';
                }
                return '';
              } catch (e) {
                print('解析sec字符串失败: $e');
                return '';
              }
            }(),
            'detail': product['secName'] ?? product['description'] ?? '', // 优先使用secName
            'detailCn': product['secName'] ?? product['description'] ?? '',
            'detailEn': product['secName'] ?? product['description'] ?? '',
            'totalPrice': price * quantity,
            'sku': product['sec'] ?? '',
            'selfSupport': () {
              dynamic value = product['selfSupport'];
              if (value == null) return 1;
              if (value is int) return value;
              if (value is String) {
                try {
                  return int.parse(value);
                } catch (e) {
                  return 1; // 解析失败时使用默认值
                }
              }
              return 1; // 其他类型时使用默认值
            }(),
            'imgUrl': product['productUrl'] ?? product['image'] ?? '', // 优先使用原始productUrl
            'taobaoFee': product['taobaoFee'] ?? product['taobaofee'] ?? 0, // 兼容两种运费字段
            'productId': product['productId'] ?? '',
            'shopId': product['shopId'] ?? '',
            // 额外保留的信息，以备后续使用
            'shopName': product['shopName'],
            'num': quantity // 商品数量
          });
        }
        
        // 计算商品总价格（包含所有运费）
        double productAllPrice = purchaseAmount + totalTaobaoFee + 0.0; // 海外运费写死为0
        
        // 计算商品总价格（包含淘宝运费，不包含海外运费）
        double productNoSeaPrice = purchaseAmount + totalTaobaoFee;
        
        // 累加总金额和总数量
        totalSumAmount += purchaseAmount;
        totalNum += totalQuantity;
        
        // 添加店铺订单数据
        orderInfoDTOList.add({
          'purchaseAmount': purchaseAmount,
          'zip': _zipcode,
          'country': '中国', // 默认中国
          'address': _detailAddress, // 使用详细地址作为地址字段
          'receiveName': _name,
          'mobilePhone': _phone,
          'currency': 'KRW', // 目前金额币种
          'num': totalQuantity,
          'shopId': shopProducts.first['shopId'], // 使用实际的店铺ID，如果没有则使用哈希码
          'cartId': cartIds,
          'message': '',//留言
          "city":"",// 市
          "district":"",// 街
          "state":"",// 省
          'personPassNo': _customsCode, // 个人通关号码
          'requestBusiness': _deliveryNotes, // 配送事项
          'houseId': 1, // 默认仓库ID
          'shopName': shopName,
          'fee': totalTaobaoFee, // 淘宝运费
          'feeSea': 0.00, // 海外运费写死为0
          'productAllPrice': productAllPrice,
          'productNoSeaPrice': productNoSeaPrice,
          'selfSupport': selfSupport, // 根据商品设置selfSupport值
          'orderProductInfoList': orderProductInfoList
        });
      });
      
      // 构建完整的订单数据结构
      Map<String, dynamic> orderData = {
        'orderAllInfo': {
          'couponId': null, // 选择的优惠券ID
          'pointsId': null, // 使用的积分数
          'sumAmount': totalSumAmount, // 购买商品总金额
          'num': totalNum // 购买商品总数
        },
        'orderInfoDTOList': orderInfoDTOList
      };
      
      // 调用创建订单接口
      final response = await HttpUtil.post(
        createOrder,
        data: orderData,
      );
      
      if (response.data['code'] == 200) {
        // 确保导航执行，即使有SnackBar
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Myorder()),
          );
        });
      } else {
        throw Exception('创建订单失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate('order_created_failed') ?? '订单创建失败'}: $e')),
      );
    } finally {
      setState(() {
        _isCreatingOrder = false;
      });
    }
  }

  // 支付相关方法已移除
  
  // 打开邮编搜索弹窗
  Future<void> _openDaumPostcode() async {
    // 使用showDialog显示中间悬浮弹窗
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.98, // 进一步增大宽度
              height: MediaQuery.of(context).size.height * 0.9, // 进一步增大高度
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 5,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 弹窗标题
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)?.translate('search_postcode') ?? '邮编搜索', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // 邮编搜索组件 - 使用Expanded确保占满剩余空间并支持滚动
                  Expanded(
                    flex: 1,
                    child: DaumPostcodeView(
                      onComplete: (model) {
                        Navigator.pop(context);
                        setState(() {
                          _zipcode = model.zonecode ?? '';
                          _address = model.address ?? '';
                          _detailAddress = model.buildingName ?? '';
                        });
                      },
                      // 配置DaumPostcodeView以支持正确的滚动行为
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建地址弹窗
  Widget _buildAddressModal(BuildContext context) {
    return Stack(
      children: [
        // 半透明背景遮罩
        GestureDetector(
          onTap: () {
            // 点击背景关闭弹窗
            setState(() {
              _showAddressModal = false;
            });
          },
          child: Container(
            color: Colors.black.withOpacity(0.5),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        // 弹窗内容
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 100),
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 5,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                // 弹窗标题
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration:  BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppLocalizations.of(context)?.translate('shipping_address') ?? '配送地址', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showAddressModal = false;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // 地址列表 - 根据状态显示不同内容
                Expanded(
                  child: _isLoadingAddress 
                    ? // 加载中状态
                      const Center(child: CircularProgressIndicator())
                    : _addressErrorMsg != null
                      ? // 错误状态
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_addressErrorMsg!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _fetchAddressList,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                      : _addressList.isEmpty
                        ? // 空地址状态
                          Center(
                            child: Text(AppLocalizations.of(context)?.translate('no_address') ?? '暂无地址', style: const TextStyle(color: Colors.grey)),
                          )
                        : // 正常显示地址列表
                          ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _addressList.length,
                            itemBuilder: (context, index) {
                              final address = _addressList[index];
                              final isSelected = _selectedAddressIndex == index;
                               
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAddressIndex = index;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected ? Colors.green : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Radio<int>(
                                            value: index,
                                            groupValue: _selectedAddressIndex,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedAddressIndex = value;
                                              });
                                            },
                                            activeColor: Colors.green,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(address['address'], style: const TextStyle(fontSize: 14)),
                                                Text('${AppLocalizations.of(context)?.translate('recipient') ?? '收件人'}: ${address['receiver']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (address['isDefault']) 
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(AppLocalizations.of(context)?.translate('default_address') ?? '默认地址', style: TextStyle(fontSize: 10, color: Colors.green)),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
                // 底部按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration:  BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedAddressIndex != null && !_isLoadingAddress
                            ? () {
                                // 确认选择地址
                                if (_selectedAddressIndex != null) {
                                  final selectedAddress = _addressList[_selectedAddressIndex!];
                                  // 填充表单数据
                                  final originalData = selectedAddress['original'];
                                  
                                  setState(() {
                                    // 赋值详细地址
                                    _detailAddress = originalData['addressDetail'] ?? '';
                                    // 赋值姓名
                                    _name = originalData['name'] ?? '';
                                    // 赋值手机号
                                    _phone = originalData['tel'] ?? '';
                                    // 关闭弹窗
                                    _showAddressModal = false;
                                  });
                                }
                              }
                            : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(AppLocalizations.of(context)?.translate('confirm_selection') ?? '确认选择', style: TextStyle(fontSize: 14, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
