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
import 'dart:math' as math;

// 创建订单页面

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
  double _exchangeRate = 0; // 默认汇率，1韩元兑换200分之一人民币（约0.005）
    
    // 表单字段控制器
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    final TextEditingController _customsCodeController = TextEditingController();
    final TextEditingController _zipcodeController = TextEditingController();
    final TextEditingController _detailAddressController = TextEditingController();
    final TextEditingController _deliveryNotesController = TextEditingController();
    
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
  
  // 用户积分
  int userPoints = 0; // 默认积分为0
  int userCoupons = 0; // 默认优惠券数为0
  bool _isLoadingPoints = false; // 积分加载状态
  
  // 积分抵扣规则
  Map<String, dynamic>? _pointsRule;
  bool _isLoadingPointsRule = false; // 积分规则加载状态
  
  // 积分抵扣相关
  int _pointsToUse = 0; // 使用的积分数量
  double _pointsDeductionAmount = 0.0; // 积分抵扣金额
  
  // 积分输入控制器
  final TextEditingController _pointsController = TextEditingController();
  
  // 优惠券相关状态
  bool _showCouponModal = false; // 控制优惠券弹窗的显示
  List<Map<String, dynamic>> _couponList = []; // 优惠券列表
  bool _isLoadingCoupons = false; // 优惠券加载状态
  Map<String, dynamic>? _selectedCoupon; // 选中的优惠券
  
  @override
  void dispose() {
    // 释放控制器资源
    _nameController.dispose();
    _phoneController.dispose();
    _customsCodeController.dispose();
    _zipcodeController.dispose();
    _detailAddressController.dispose();
    _deliveryNotesController.dispose();
    // _pointsController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    // 打印接收到的商品数据
    _fetchUserPoints(); // 获取用户积分
    _fetchPointsRule(); // 获取积分抵扣规则
    // 初始化时获取优惠券列表
    _fetchCouponList();
  }

    // 加载汇率
  // void _loadExchangeRate() async {
  //   try {
  //     final response = await HttpUtil.get(
  //       searchRateUrl,
  //       queryParameters: {
  //         'currency': 1,  // 根据search.dart中的修改，这里应该是2表示韩元
  //         'type': 1,
  //         'benchmarkCurrency': 2  // 1表示人民币
  //       },
  //     );
      
  //     if (response.data['code'] == 200) {
  //       final rateData = response.data['data'];
  //       if (rateData != null) {
  //         setState(() {
  //           _exchangeRate = rateData.toDouble();
  //         });
  //         print('汇率更新成功: $_exchangeRate');
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("汇率查询失败：$e");
  //   }
  // }
  
  // 从API获取用户积分
  Future<void> _fetchUserPoints() async {
    setState(() {
      _isLoadingPoints = true;
    });
    
    try {
      // 调用专门的积分接口获取积分
      var response = await HttpUtil.get(getUserPointsUrl);
      if (response.data != null) {
        Map<String, dynamic> responseData = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (responseData['code'] == 200 && responseData['data'] != null) {
          setState(() {
            // 更新积分，若为null则设为0
            userPoints = int.tryParse(responseData['data']['points']?.toString() ?? '0') ?? 0;
            // 优惠券数量不再从该接口获取，改为从优惠券列表接口的total字段获取
          });
        }
      }
    } catch (e) {
      developer.log('获取用户积分和优惠券失败: $e');
    } finally {
      setState(() {
        _isLoadingPoints = false;
      });
    }
  }
  
  // 从API获取积分抵扣规则
  Future<void> _fetchPointsRule() async {
    setState(() {
      _isLoadingPointsRule = true;
    });
    
    try {
      // 调用积分抵扣规则接口
      var response = await HttpUtil.get(pointsDeductionRulesUrl);
      if (response.data != null) {
        Map<String, dynamic> responseData = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (responseData['code'] == 200 && responseData['data'] != null) {
          setState(() {
            _pointsRule = responseData['data'];
          });
        }
      }
    } catch (e) {
      developer.log('获取积分抵扣规则失败: $e');
    } finally {
      setState(() {
        _isLoadingPointsRule = false;
      });
    }
  }
  
  // 从API获取优惠券列表
  Future<void> _fetchCouponList() async {
    setState(() {
      _isLoadingCoupons = true;
    });
    
    try {
      // 调用优惠券列表接口
      var response = await HttpUtil.get(couponListUrl);
      if (response.data != null) {
        Map<String, dynamic> responseData = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (responseData['code'] == 200) {
          setState(() {
            if (responseData['data'] != null) {
              _couponList = List<Map<String, dynamic>>.from(responseData['data']);
            }
            // 使用新API响应中的total字段更新优惠券数量
            userCoupons = responseData['total'] ?? 0;
          });
        }
      }
    } catch (e) {
      developer.log('获取优惠券列表失败: $e');
    } finally {
      setState(() {
        _isLoadingCoupons = false;
      });
    }
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
  
  // 缓存处理后的商品数据
  List<Map<String, dynamic>>? _cachedProducts;
  
  // 缓存商品统计信息
  Map<String, dynamic>? _cachedProductStats;
  
  // 获取处理后的商品数据（带缓存）
  List<Map<String, dynamic>> _getProductsData() {
    // 如果缓存为空，重新计算
    if (_cachedProducts == null) {
      _cachedProducts = _prepareProductsData();
    }
    return _cachedProducts!;
  }
  
  // 获取商品统计信息（带缓存）
  Map<String, dynamic> _getProductStats() {
    // 如果缓存为空，重新计算
    if (_cachedProductStats == null) {
      final List<Map<String, dynamic>> products = _getProductsData();
      
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
        // 先对单价四舍五入，再乘以数量，避免浮点数累加误差（与sumAmount计算逻辑一致）
        totalPrice += (price).roundToDouble() * quantity;
        
        // 累加每个商品的淘宝运费
        double productTaobaoFee = (product['taobaofee'] ?? 0.0).toDouble();
        totalTaobaoFee += productTaobaoFee;
      }
      
      // 将运费加到总价上，并对结果进行四舍五入（与sumAmount计算逻辑一致）
      totalPrice += totalTaobaoFee;
      totalPrice = totalPrice.roundToDouble();
      
      _cachedProductStats = {
        'categoryCount': uniqueProducts.length,
        'totalQuantity': totalQuantity,
        'totalPrice': totalPrice
      };
    }
    return _cachedProductStats!;
  }
  
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
      // 先对单价四舍五入，再乘以数量，避免浮点数累加误差（与sumAmount计算逻辑一致）
      totalPrice += (price).roundToDouble() * quantity;
      
      // 累加每个商品的淘宝运费
      double productTaobaoFee = (product['taobaofee'] ?? 0.0).toDouble();
      totalTaobaoFee += productTaobaoFee;
    }
    
    // 将运费加到总价上，并对结果进行四舍五入（与sumAmount计算逻辑一致）
    totalPrice += totalTaobaoFee;
    totalPrice = totalPrice.roundToDouble();
    
    // 移除不必要的打印语句
    // print('计算的商品总价: $totalPrice, 总运费: $totalTaobaoFee');
    
    // 直接返回缓存的统计信息
    return _getProductStats();
  }
  
  // 准备商品数据，将购物车数据转换为Payment页面需要的格式
  List<Map<String, dynamic>> _prepareProductsData() {
    // 移除不必要的打印语句，只在调试时使用
    // print('准备处理的商品数据: $selectedProducts');
    // print('原始商品数据是否为空: ${selectedProducts.isEmpty}');

    
    List<Map<String, dynamic>> result = [];
    // print('开始处理店铺数据，共有${selectedProducts.length}个店铺');
    
    
    // 处理购物车数据结构
    for (var shopData in selectedProducts) {
      String shopName = shopData['shopName'];
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
          'image': item['productUrl']?.replaceAll('`', '')?.trim() ?? '',
          'name': item['productNameCn'] ?? item['productName'] ?? '商品名称',
          'description': item['secName'] ?? '商品描述',
          'color': color,
          'quantity': item['num'] ?? 1,
          'price': item['productPlusPrice'] ?? item['productPrice'] ?? 0,
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
                      '₩${(double.tryParse(product['price']?.toString() ?? '0') ?? 0).round().toString()}',
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
    final List<Map<String, dynamic>> products = _getProductsData();

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
    bool readOnly = false;
    TextEditingController? controller;
    
    // 根据字段名设置控制器和只读状态
    switch (fieldName) {
      case 'postal_code':
        controller = _zipcodeController;
        break;
      case 'address':
        readOnly = true; // 地址字段只读，通过搜索邮编填充
        break;
      case 'detail_address':
        controller = _detailAddressController;
        break;
      case 'name':
        controller = _nameController;
        break;
      case 'phone':
        controller = _phoneController;
        break;
      case 'customs_code':
        controller = _customsCodeController;
        break;
      case 'delivery_notes':
        controller = _deliveryNotesController;
        break;
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
                  // 清除缓存，表单变化不影响商品数据
                  // _cachedProducts = null;
                  // _cachedProductStats = null;
                  
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
            controller: controller,
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
// Future<List<Map<String, dynamic>>> _fetchPaymentCardsAsync() async {
//   try {
//     final response = await HttpUtil.get(cardlist);
//     if (response.statusCode == 200 && response.data['code'] == 200) {
//       List<dynamic> data = response.data['data'] ?? [];
//       return List<Map<String, dynamic>>.from(data);
//     } else {
//       throw Exception(response.data['msg'] ?? '接口返回失败');
//     }
//   } catch (e) {
//     throw Exception(e.toString());
//   }
// }


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
          // 优惠券弹窗
          _showCouponModal ? _buildCouponModal(context) : Container(),
        ],
      ),
    );
  }

  // 计算积分抵扣金额
  void _calculatePointsDeduction() {
    if (_pointsRule == null) {
      setState(() {
        _pointsDeductionAmount = 0.0;
        _pointsToUse = 0;
      });
      return;
    }
    
    // 获取积分抵扣系数（1积分等于多少韩元）
    double pointMoney = double.tryParse(_pointsRule!['pointMoney']?.toString() ?? '1') ?? 1.0;
    
    // 计算积分能抵扣的金额（积分数量 * pointMoney）
    double deductionAmount = _pointsToUse * pointMoney;
    
    // 确保抵扣金额不超过商品总价
    Map<String, dynamic> productStats = _getProductStats();
    double totalPrice = productStats['totalPrice'] ?? 0.0;
    
    // 如果抵扣金额超过总价，则只抵扣总价
    if (deductionAmount > totalPrice) {
      deductionAmount = totalPrice;
      // 计算实际能使用的积分数量
      _pointsToUse = (deductionAmount / pointMoney).ceil();
      // 更新积分输入框
      _pointsController.text = _pointsToUse.toString();
    }
    
    setState(() {
      _pointsDeductionAmount = deductionAmount.roundToDouble(); // 积分抵扣金额进行四舍五入
    });
  }
  

  
  // 使用全额积分
  void _useAllPoints() {
    if (_pointsRule == null) return;
    
    // 获取积分抵扣系数（1积分等于多少韩元）
    double pointMoney = double.tryParse(_pointsRule!['pointMoney']?.toString() ?? '1') ?? 1.0;
    
    setState(() {
      Map<String, dynamic> productStats = _getProductStats();
      double totalPrice = productStats['totalPrice'] ?? 0.0;
      
      // 计算最大可使用积分（不超过用户可用积分和能抵扣的最大积分）
      int maxPointsForPrice = (totalPrice / pointMoney).floor();
      _pointsToUse = math.min(userPoints, maxPointsForPrice);
      _pointsController.text = _pointsToUse.toString();
      // 优惠券和积分互斥使用，使用积分则清空优惠券
      _selectedCoupon = null;
      _calculatePointsDeduction();
    });
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(AppLocalizations.of(context)?.translate('points') ?? '积分', style:  TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      // 全额使用按钮
                      GestureDetector(
                        onTap: () {
                          // 检查是否满足积分使用条件
                          bool canUsePoints = false;
                          if (_pointsRule != null) {
                            double pointsUsedThreshold = double.tryParse(_pointsRule!['pointUsed'] ?? '0') ?? 0.0;
                            Map<String, dynamic> productStats = _getProductStats();
                            double totalPrice = productStats['totalPrice'] ?? 0.0;
                            
                            // 检查是否满足积分使用条件
                            canUsePoints = totalPrice >= pointsUsedThreshold;
                          }
                          
                          if (canUsePoints) {
                            _useAllPoints();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(AppLocalizations.of(context)?.translate('use_all') ?? '全额使用', style:  TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // 右侧：可用积分信息、输入框和全额显示
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  //  可用优惠券信息
                  GestureDetector(
                    onTap: () {
                      // 点击优惠券显示弹窗
                      setState(() {
                        _showCouponModal = true;
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppLocalizations.of(context)?.translate('available_points') ?? '可用优惠券', style:  TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        _isLoadingPoints 
                          ? const CircularProgressIndicator(strokeWidth: 1) 
                          : Text('$userCoupons${AppLocalizations.of(context)?.translate('pointss') ?? '张'}', style:  TextStyle(fontSize: 12, color: const Color.fromARGB(255, 0, 255, 106))),
                        const SizedBox(width: 5),
                        const Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 积分输入框和P单位
                  Row(
                    children: [
                      // 积分输入框（缩小高度）
                      SizedBox(
                        width: 80,
                        height: 28,
                        child: TextField(
                          controller: _pointsController,
                          enabled: () {
                            // 检查是否满足积分使用条件
                            if (_pointsRule == null) return false;
                            
                            double pointsUsedThreshold = double.tryParse(_pointsRule!['pointUsed'] ?? '0') ?? 0.0;
                            Map<String, dynamic> productStats = _getProductStats();
                            double totalPrice = productStats['totalPrice'] ?? 0.0;
                            
                            // 检查是否满足积分使用条件
                            return totalPrice >= pointsUsedThreshold;
                          }(),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (value.isEmpty) {
                              _pointsToUse = 0;
                              _calculatePointsDeduction();
                              return;
                            }
                            
                            int points = int.tryParse(value) ?? 0;
                            // 确保积分不超过用户可用积分
                            points = points > userPoints ? userPoints : points;
                            // 确保积分不小于0
                            points = points < 0 ? 0 : points;
                            
                            setState(() {
                              _pointsToUse = points;
                              _pointsController.text = points.toString();
                              // 设置光标位置到文本末尾
                              _pointsController.selection = TextSelection.fromPosition(TextPosition(offset: _pointsController.text.length));
                              // 优惠券和积分互斥使用，使用积分则清空优惠券
                              if (points > 0) {
                                _selectedCoupon = null;
                              }
                            });
                            
                            _calculatePointsDeduction();
                          },
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(AppLocalizations.of(context)?.translate('points_unit') ?? 'P', style:  TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 全额积分显示
                  Text('${AppLocalizations.of(context)?.translate('total') ?? '全额'}: $userPoints${AppLocalizations.of(context)?.translate('points_unit') ?? 'P'}', style:  TextStyle(fontSize: 12)),
                  const SizedBox(height: 5),
                  // 积分抵扣金额显示
                  // if (_pointsDeductionAmount > 0)
                  //   Text('${AppLocalizations.of(context)?.translate('points_deduction') ?? '积分抵扣'}: -₩${_pointsDeductionAmount.round().toString()}', 
                  //     style:  TextStyle(fontSize: 12, color: Colors.red)),
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
    
    // 格式化价格，添加千位分隔符和韩元符号，四舍五入去除小数
    String formattedPrice = '₩${totalPrice.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (Match m) => ',')}';
    
    // 计算优惠券抵扣金额
    double couponDeductionAmount = 0.0;
    if (_selectedCoupon != null) {
      if (_selectedCoupon!['type'] == '1') { // 满减券
        couponDeductionAmount = double.tryParse(_selectedCoupon!['returnAmount']?.toString() ?? '0') ?? 0.0;
      } else if (_selectedCoupon!['type'] == '2') { // 折扣券
        double discountRate = double.tryParse(_selectedCoupon!['returnAmount']?.toString() ?? '100') ?? 100.0;
        discountRate = discountRate / 100.0; // 转换为折扣率（如75变为0.75）
        couponDeductionAmount = totalPrice - (totalPrice * discountRate);
      }
    }
    
    // 计算最终支付金额
    double finalAmount = totalPrice - couponDeductionAmount - _pointsDeductionAmount;
    finalAmount = finalAmount < 0 ? 0 : finalAmount;
    
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
                    Text(formattedPrice, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.green)),
                    // 优惠券抵扣金额显示
                    if (couponDeductionAmount > 0)
                      Text('${AppLocalizations.of(context)?.translate('coupon_deduction') ?? '优惠券抵扣'}: -₩${couponDeductionAmount.round().toString()}', 
                        style: const TextStyle(fontSize: 14, color: Colors.red)),
                    // 积分抵扣金额显示
                    if (_pointsDeductionAmount > 0)
                      Text('${AppLocalizations.of(context)?.translate('points_deduction') ?? '积分抵扣'}: -₩${_pointsDeductionAmount.round().toString()}', 
                        style: const TextStyle(fontSize: 14, color: Colors.red)),
                    // 最终支付金额显示
                    if (couponDeductionAmount > 0 || _pointsDeductionAmount > 0)
                      Text('${AppLocalizations.of(context)?.translate('final_pay') ?? '实付金额'}: ₩${finalAmount.round().toString()}', 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
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

      // 准备商品数据（直接使用prepare方法，确保获取最新数据）
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
          
          // 先对单个商品总价进行四舍五入，避免浮点数累加误差
          purchaseAmount += (price).roundToDouble() * quantity;
          totalTaobaoFee += taobaoFee;
          totalQuantity += quantity;
          
          // 添加购物车ID（使用实际的cartId）
          if (cartIds.isNotEmpty) cartIds += ',';
          cartIds += '${product['cartId'] ?? product.hashCode}';
          
          // 构建订单商品信息
          orderProductInfoList.add({
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
            'quantity': quantity,
            'price': price.round(), // 单个商品价格（与UI显示一致，进行四舍五入）
            // 使用保留的原始字段信息
            'title': product['productName'] ?? product['name'], // 优先使用原始productName
            'titleEn': product['productNameEn'] ?? product['productName'] ?? product['name'],
            'titleCn': product['productNameCn'] ?? product['productName'] ?? product['name'],
            'skuId': () {
              try {
                // 解析sec字符串为JSON对象并获取spmpId
                if (product['sec'] != null && product['sec'] is String && product['sec'].isNotEmpty) {
                  final Map<String, dynamic> secJson = jsonDecode(product['sec']);
                  return secJson['spmpId'] ?? '';
                }
                return '';
              } catch (e) {
                return '';
              }
            }(),
            'detail': product['secName'] ?? product['description'] ?? '', // 优先使用secName
            'detailCn': product['secName'] ?? product['description'] ?? '',
            'detailEn': product['secName'] ?? product['description'] ?? '',
            'totalPrice': (price * quantity).round(), // 单个商品总价（与UI显示一致，进行四舍五入）
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
            'imgUrl': product['productUrl'] ?? product['image'] ?? '' // 优先使用原始productUrl
          });
        }
        
        // 计算商品总价格（包含所有运费）
        double productAllPrice = (purchaseAmount + totalTaobaoFee + 0.0).roundToDouble(); // 海外运费写死为0
        
        // 计算商品总价格（包含淘宝运费，不包含海外运费）
        double productNoSeaPrice = (purchaseAmount + totalTaobaoFee).roundToDouble();
        
        // 累加总金额和总数量，包含淘宝运费（使用四舍五入后的值）
        totalSumAmount += (purchaseAmount + totalTaobaoFee).round();
        totalNum += totalQuantity;
        
        // 添加店铺订单数据
        orderInfoDTOList.add({
          'purchaseAmount': purchaseAmount.round(), // 商品总金额（与UI显示一致，进行四舍五入）
          'zip': _zipcode,
          'num': totalQuantity,
          'shopId': shopProducts.first['shopId'], // 使用实际的店铺ID，如果没有则使用哈希码
          'cartId': cartIds,
          'shopName': shopName,
          'fee': totalTaobaoFee.round(), // 淘宝运费（与UI显示一致，进行四舍五入）
          'productAllPrice': productAllPrice,
          'productNoSeaPrice': productNoSeaPrice,
          'selfSupport': selfSupport, // 根据商品设置selfSupport值
          'requestBusiness': _deliveryNotes, // 配送事项
          'personPassNo': _customsCode, // 个人通关号码
          'picture': orderProductInfoList.isNotEmpty ? orderProductInfoList.first['imgUrl'] : '',
          'orderProductInfoList': orderProductInfoList
        });
      });
      
      // 检查是否满足积分使用条件
      bool canUsePoints = false;
      if (_pointsRule != null && _pointsToUse > 0) {
        double pointsUsedThreshold = double.tryParse(_pointsRule!['pointUsed'] ?? '0') ?? 0.0;
        Map<String, dynamic> productStats = _getProductStats();
        double totalPrice = productStats['totalPrice'] ?? 0.0;
        
        // 检查是否满足积分使用条件
        canUsePoints = totalPrice >= pointsUsedThreshold;
      }
      
      // 如果不满足积分使用条件，重置积分使用状态
      if (_pointsToUse > 0 && !canUsePoints) {
        setState(() {
          _pointsToUse = 0;
          _pointsController.text = '';
          _pointsDeductionAmount = 0.0;
        });
      }
      
      // 计算最终金额（减去积分和优惠券抵扣）
      double finalAmount = totalSumAmount;
      double couponDeductionAmount = 0.0;
      
      // 减去优惠券抵扣
      if (_selectedCoupon != null) {
        if (_selectedCoupon!['type'] == '1') { // 满减券
          couponDeductionAmount = double.tryParse(_selectedCoupon!['returnAmount']?.toString() ?? '0') ?? 0.0;
        } else if (_selectedCoupon!['type'] == '2') { // 折扣券
          double discountRate = double.tryParse(_selectedCoupon!['returnAmount']?.toString() ?? '100') ?? 100.0;
          discountRate = discountRate / 100.0; // 转换为折扣率（如75变为0.75）
          couponDeductionAmount = totalSumAmount - (totalSumAmount * discountRate);
        }
        
        if (couponDeductionAmount > 0) {
          finalAmount -= couponDeductionAmount;
        }
      }
      
      // 减去积分抵扣
      if (_pointsToUse > 0 && _pointsDeductionAmount > 0) {
        finalAmount -= _pointsDeductionAmount;
      }
      
      // 确保最终金额不小于0
      finalAmount = finalAmount < 0 ? 0 : finalAmount;
      
      // 四舍五入到两位小数
      finalAmount = double.parse(finalAmount.toStringAsFixed(2));
      
      // 构建完整的订单数据结构
      Map<String, dynamic> orderData = {
        'orderAllInfo': {
          'couponId': _selectedCoupon != null ? _selectedCoupon!['couponUseId'] ?? 0 : 0, // 选择的优惠券ID（使用couponUseId）
          'pointsId': _pointsToUse, // 使用的积分数
          'sumAmount': totalSumAmount.round(), // 购买商品总金额（与UI显示一致，进行四舍五入）
          'num': totalNum, // 购买商品总数
          'selfSupport': orderInfoDTOList.isNotEmpty ? orderInfoDTOList.first['selfSupport'] ?? 1 : 1, // 是否自营1否 2是
          'fee': orderInfoDTOList.fold(0.0, (sum, item) => sum + (item['fee'] ?? 0.0)), // 淘宝运费
          'productAllPrice': finalAmount.round(), // 商品总价格（与UI显示一致，进行四舍五入）
          'productNoSeaPrice': orderInfoDTOList.fold(0.0, (sum, item) => sum + (item['productNoSeaPrice'] ?? 0.0)).round(), // 商品总价格（与UI显示一致，进行四舍五入）
          'houseId': 1, // 仓库ID 默认为1
          'message': '', // 买家留言
          'zip': _zipcode, // 邮政编码
          'country': '中国', // 国家，默认中国
          'address': _detailAddress, // 详细地址
          'city': '', // 市，目前未收集
          'district': '', // 街，目前未收集
          'mobilePhone': _phone, // 接收人手机号
          'receiveName': _name, // 接收人姓名
          'state': '', // 省，目前未收集
          'requestBusiness': _deliveryNotes, // 配送事项
          'personPassNo': _customsCode, // 个人通过编码
          'currency': 'KRW', // 目前金额币种
          'couponAmount': couponDeductionAmount, // 优惠券抵扣金额
          'picture': orderInfoDTOList.isNotEmpty ? (orderInfoDTOList.first['orderProductInfoList'] is List && (orderInfoDTOList.first['orderProductInfoList'] as List).isNotEmpty ? (orderInfoDTOList.first['orderProductInfoList'] as List).first['imgUrl'] : '') : ''
        },
        'orderInfoDTOList': orderInfoDTOList
      };
      
      // 如果使用积分，需要将总金额减去积分抵扣金额
      // if (canUsePoints && _pointsToUse > 0) {
      //   // 处理浮点数精度问题，保留两位小数
      //   double finalAmount = (totalSumAmount - _pointsDeductionAmount);
      //   // 四舍五入到两位小数
      //   finalAmount = double.parse(finalAmount.toStringAsFixed(2));
      //   orderData['orderAllInfo']['sumAmount'] = finalAmount;
      // }
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
                          _zipcodeController.text = _zipcode;
                          _address = model.address ?? '';
                          _detailAddress = model.buildingName ?? '';
                          _detailAddressController.text = _detailAddress;
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
                                    _detailAddressController.text = _detailAddress;
                                    // 赋值姓名
                                    _name = originalData['name'] ?? '';
                                    _nameController.text = _name;
                                    // 赋值手机号
                                    _phone = originalData['tel'] ?? '';
                                    _phoneController.text = _phone;
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
  
  // 构建优惠券弹窗
  Widget _buildCouponModal(BuildContext context) {
    return Stack(
      children: [
        // 半透明背景遮罩
        GestureDetector(
          onTap: () {
            // 点击背景关闭弹窗
            setState(() {
              _showCouponModal = false;
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
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
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
                      Text(AppLocalizations.of(context)?.translate('coupon') ?? '优惠券', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showCouponModal = false;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // 优惠券列表
                Expanded(
                  child: _isLoadingCoupons
                      ? const Center(child: CircularProgressIndicator())
                      : _couponList.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context)?.translate('no_coupons_available') ?? '暂无可用优惠券'))
                          : ListView.builder(
                              itemCount: _couponList.length,
                              itemBuilder: (context, index) {
                                final coupon = _couponList[index];
                                
                                // 根据优惠券状态设置颜色
                                // 根据优惠券的实际状态进行判断
                                bool isAvailable = coupon['couponUse'] == '1'; // 1否 2是
                                
                                // 判断是否满足金额条件
                                Map<String, dynamic> productStats = _getProductStats();
                                double totalPrice = productStats['totalPrice'] ?? 0.0;
                                double couponAmount = (coupon['amount'] ?? 0).toDouble();
                                bool meetsAmountCondition = totalPrice >= couponAmount;
                                
                                // 只有当优惠券可用且满足金额条件时，才可以使用
                                bool canUse = isAvailable && meetsAmountCondition;
                                
                                String statusText = isAvailable ? (meetsAmountCondition ? '立即使用' : '金额不足') : '已使用';
                                Color mainColor = canUse ? const Color(0xFFE63B3B) : Colors.grey;
                                Color textColor = isAvailable ? Colors.black : Colors.grey;
                                Color timeColor = isAvailable ? const Color(0xFFE63B3B) : Colors.grey;
                                
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.shade100,
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // 优惠券内容
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            // 金额/折扣部分
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // 根据优惠券类型显示折扣或满减金额
                                                  if (coupon['type'] == '1') // 满减券
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                                      textBaseline: TextBaseline.alphabetic,
                                                      children: [
                                                        const Text(
                                                          '₩', // 韩元符号
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${coupon['returnAmount']}', // 显示满减金额
                                                          style: TextStyle(
                                                            fontSize: 36,
                                                            fontWeight: FontWeight.bold,
                                                            color: mainColor,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  else if (coupon['type'] == '2') // 折扣券
                                                    Text(
                                                      '${((double.tryParse(coupon['returnAmount']?.toString() ?? '0') ?? 0.0) / 10).toStringAsFixed(1)}折', // 转换为折扣显示，确保有默认值
                                                      style: TextStyle(
                                                        fontSize: 36,
                                                        fontWeight: FontWeight.bold,
                                                        color: mainColor,
                                                      ),
                                                    ),
                                                  // 显示使用条件：满多少金额
                                                  Text(
                                                    '满${coupon['amount']}可用',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 中间内容部分
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${coupon['type'] == '1' ? '满减券' : '折扣券'}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: textColor,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // 显示使用时间
                                                  Text(
                                                    '${coupon['startTime']} - ${coupon['endTime']}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[500],
                                                    ),
                                                    softWrap: true,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // 状态按钮
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      if (canUse) {
                                                        // 立即使用优惠券，同时清空积分使用
                                                        setState(() {
                                                          _selectedCoupon = coupon;
                                                          _showCouponModal = false;
                                                          // 优惠券和积分互斥使用，选择优惠券则清空积分
                                                          _pointsToUse = 0;
                                                          _pointsController.text = '';
                                                          _pointsDeductionAmount = 0.0;
                                                        });
                                                        // 这里可以添加选择优惠券后的逻辑
                                                        print('选中的优惠券: $coupon');
                                                      }
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: mainColor,
                                                        borderRadius: BorderRadius.circular(16),
                                                      ),
                                                      child: Text(
                                                        statusText,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        softWrap: false,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // 格式化剩余时间
  String _formatRemainingTime(DateTime endTime) {
    Duration remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) return '已过期';
    
    int hours = remaining.inHours;
    int minutes = remaining.inMinutes.remainder(60);
    int seconds = remaining.inSeconds.remainder(60);
    
    return '$hours:$minutes:$seconds';
  }
}

// 添加优惠券弹窗到Widget树
// 注意：在实际应用中，这部分应该添加到build方法的Scaffold中
// 由于我们无法直接修改build方法，这里只是展示优惠券弹窗的实现
// 在实际项目中，需要在build方法的return Scaffold(...)中添加以下代码：
// if (_showCouponModal)
//   _buildCouponModal(context),
