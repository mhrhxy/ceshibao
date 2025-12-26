import 'dart:convert';
import 'package:flutter/material.dart';
import 'Payment.dart';
import 'utils/http_util.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'productdetails.dart';
import 'package:flutter_mall/app_localizations.dart';

// 购物车页面

class Product {
  final String id;

  Product({required this.id});
}

class CartItem {
  final int cartId;
  final int productId;
  final int secId;
  final int memberId;
  final int shopId; // 添加店铺ID字段
  bool isSelected;
  final String productUrl;
  final String productName;
  final String secName;
  final double productPrice;
  final double? productPlusPrice; // 会员价字段，可为空
  final double productPriceKRW; // 商品单价韩元
  final double? productPlusPriceKRW; // 商品会员单价韩元
  int num;
  final String shopName;
  double taobaoFee; // 添加淘宝运费字段
  final String sec; // 添加sec字段，用于Payment页面解析skuId等信息
  final int selfSupport; // 添加selfSupport字段

  CartItem({
    required this.cartId,
    required this.productId,
    required this.secId,
    required this.memberId,
    required this.shopId, // 添加shopId参数
    this.isSelected = false,
    required this.productUrl,
    required this.productName,
    required this.secName,
    required this.productPrice,
    this.productPlusPrice, // 会员价参数，可选
    required this.productPriceKRW, // 添加商品单价韩元参数
    this.productPlusPriceKRW, // 添加商品会员单价韩元参数
    required this.num,
    required this.shopName,
    this.taobaoFee = 0.0, // 初始化运费为0
    required this.sec, // 添加sec参数
    required this.selfSupport, // 添加selfSupport参数
  });

  factory CartItem.fromJson(Map<String, dynamic> json, int memberId) {
    // 从cart对象中获取商品信息
    final Map<String, dynamic> cartData = json['cart'] ?? {};
    
    // 确保sec字段有默认值，避免null
    final secValue = cartData['sec'] ?? '{}';
    // 解析selfSupport字段，处理不同类型
    int selfSupport = 1; // 默认值
    dynamic selfSupportValue = cartData['selfSupport'];
    if (selfSupportValue != null) {
      if (selfSupportValue is int) {
        selfSupport = selfSupportValue;
      } else if (selfSupportValue is String) {
        try {
          selfSupport = int.parse(selfSupportValue);
        } catch (e) {
          // 解析失败使用默认值
        }
      }
    }
    return CartItem(
      cartId: cartData['cartId'] ?? 0,
      productId: cartData['productId'] ?? 0,
      secId: cartData['secId'] ?? 0,
      memberId: memberId,
      shopId: cartData['shopId'] ?? 0, // 从JSON初始化shopId
      productUrl: cartData['productUrl'] ?? '',
      productName: cartData['productName'] ?? '未知商品',
      secName: cartData['secName'] ?? '옵션:A  변경',
      productPrice: (cartData['productPrice'] ?? 0).toDouble(),
      productPlusPrice: cartData['productPlusPrice'] != null ? (cartData['productPlusPrice']).toDouble() : null, // 从JSON初始化会员价
      productPriceKRW: (json['productPriceKRW'] ?? 0).toDouble(), // 从JSON初始化商品单价韩元
      productPlusPriceKRW: json['productPlusPriceKRW'] != null ? (json['productPlusPriceKRW']).toDouble() : null, // 从JSON初始化商品会员单价韩元
      num: cartData['num'] ?? 1,
      shopName: cartData['shopName'] ?? '쇼핑몰A',
      taobaoFee: (cartData['taobaoFee'] ?? 0).toDouble(), // 从JSON初始化运费
      sec: secValue, // 从JSON初始化sec字段
      selfSupport: selfSupport, // 从JSON初始化selfSupport字段
    );
  }
}

class Shop {
  final String shopName;
  bool isAllSelected;
  final List<CartItem> items;

  Shop({
    required this.shopName,
    this.isAllSelected = false,
    required this.items,
  });

  factory Shop.fromJson(Map<String, dynamic> json, int memberId) {
    var cartList = json['cartList'] as List? ?? [];
    List<CartItem> items =
        cartList.map((item) => CartItem.fromJson(item, memberId)).toList();
    return Shop(shopName: json['shopName'] ?? '쇼핑몰A', items: items);
  }
}

class CollectItem {
  final int collectId;
  final int productId;
  final String productNameCn;
  final double? productPrice;
  final String shopName;
  final String productUrl;

  CollectItem({
    required this.collectId,
    required this.productId,
    required this.productNameCn,
    this.productPrice,
    required this.shopName,
    required this.productUrl,
  });

  factory CollectItem.fromJson(Map<String, dynamic> json) {
    return CollectItem(
      collectId: json['collectId'] ?? 0,
      productId: json['productId'] ?? 0,
      productNameCn: json['productNameCn'] ?? '未知商品',
      productPrice:
          json['productPrice'] != null ? (json['productPrice'] as num).toDouble() : null,
      shopName: json['shopName'] ?? '未知店铺',
      productUrl: json['productUrl'] ?? '',
    );
  }
}

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  List<Shop> _shops = [];
  List<CollectItem> _collectItems = [];
  bool _isLoading = true;
  String? _errorMsg;
  int _currentTab = 0;
  String? _token;
  int? _memberId;
  final Map<int, double> _itemOffset = {};
  int _selectedTag = 0;
  // 1表示直购商品，2表示推荐商品
  int _selfSupport = 1;

  int _currentCollectPage = 1;
  final int _collectPageSize = 20;
  bool _isCollectLoading = false;
  bool _hasMoreCollect = true;
  final ScrollController _collectScrollController = ScrollController();

  // 弹窗状态
  bool _showShippingInfo = false;
  bool _showShippingFeeList = false;
  bool _showDisclaimer = false;

  // 新增：运费列表相关状态
  List<Map<String, dynamic>> _shippingFeeList = [];
  bool _isLoadingFee = false;
  String? _feeErrorMsg;
  
  // 新增：汇率相关状态
  double? _exchangeRate;
  bool _isLoadingRate = false;
  String? _rateErrorMsg;
  
  // 淘宝运费相关状态
  double _taobaoFee = 0.0;
  bool _isLoadingTaobaoFee = false;
  String? _taobaoFeeErrorMsg;
  // 存储每个商品的单独运费，key为productId
  Map<String, double> _itemTaobaoFees = {};

  @override
  void initState() {
    super.initState();
    _initTokenAndMemberId();
    _loadExchangeRate(); // 加载汇率
    _collectScrollController.addListener(() {
      if (_collectScrollController.position.pixels ==
              _collectScrollController.position.maxScrollExtent &&
          _currentTab == 1 &&
          !_isCollectLoading &&
          _hasMoreCollect) {
        _loadMoreCollectList();
      }
    });
  }
  
  // 新增：加载汇率方法
  Future<void> _loadExchangeRate() async {
    if (_isLoadingRate) return;
    
    setState(() {
      _isLoadingRate = true;
      _rateErrorMsg = null;
    });
    
    try {
      // 使用HttpUtil发送请求，保留相同的查询参数
      final response = await HttpUtil.get(searchRateUrl, queryParameters: {
        'currency': 2,  // 2表示韩元
        'type': 1,
        'benchmarkCurrency': 1  // 1表示人民币
      });
      
      // 根据接口返回格式调整：{msg: "操作成功", code: 200, data: 199}
      if (response.data['code'] == 200) {
        var rateData = response.data['data'];
        if (rateData != null) {
          setState(() {
            _exchangeRate = rateData.toDouble();
          });
        }
      } else {
        throw Exception(response.data['msg'] ?? '获取汇率失败');
      }
    } catch (e) {
      setState(() {
        _rateErrorMsg = e.toString().replaceAll('Exception: ', '');
        // 如果获取汇率失败，设置默认汇率
        _exchangeRate = 199.0;
      });
      debugPrint('汇率接口请求失败: $e');
    } finally {
      setState(() {
        _isLoadingRate = false;
      });
    }
  }

  @override
  void dispose() {
    _collectScrollController.dispose();
    super.dispose();
  }

  Future<void> _initTokenAndMemberId() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    final String? memberInfoJson = prefs.getString('member_info');
    if (memberInfoJson == null || memberInfoJson.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = AppLocalizations.of(context)?.translate('member_info_missing') ?? "会员信息缺失，请重新登录";
      });
      return;
    }

    try {
      final Map<String, dynamic> memberInfo = jsonDecode(memberInfoJson);
      _memberId = memberInfo['memberId'] as int?;
      if (_memberId == null) throw Exception(AppLocalizations.of(context)?.translate('member_id_missing') ?? "会员ID不存在");
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = AppLocalizations.of(context)?.translate('member_info_parse_failed') ?? "会员信息解析失败，请重新登录";
      });
      return;
    }

    _fetchCartList();
  }

  Future<void> _fetchCartList() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      if (_token == null || _token!.isEmpty) throw Exception(AppLocalizations.of(context)?.translate('please_login_first') ?? '请先登录');
      if (_memberId == null) throw Exception(AppLocalizations.of(context)?.translate('member_id_missing') ?? '会员ID缺失');

      final response = await HttpUtil.get(
        cartlist,
        queryParameters: {
          'selfSupport': _selfSupport,
        },
      );
      if (response.data['code'] == 200) {
        List<dynamic> shopJsonList = response.data['data'] ?? [];
        setState(() {
          _shops = shopJsonList
              .map((shopJson) => Shop.fromJson(shopJson, _memberId!))
              .toList();
          for (var shop in _shops) {
            for (var item in shop.items) {
              _itemOffset[item.cartId] = 0.0;
            }
          }
        });
      } else {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('fetch_cart_failed') ?? '获取购物车数据失败');
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
      debugPrint('购物车接口请求失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 获取淘宝运费的方法
  Future<void> _fetchTaobaoFee() async {
    // 收集选中的商品
    List<Map<String, dynamic>> selectedItems = [];
    for (var shop in _shops) {
      for (var item in shop.items) {
        if (item.isSelected) {
          selectedItems.add({
            "itemId": item.productId,
            "fee": 0, // 海外运费默认传0
            "type": 1 // 商品类型默认传1（淘宝商品）
          });
        }
      }
    }
    
    // 如果没有选中的商品，设置运费为0
    if (selectedItems.isEmpty) {
      setState(() {
        _taobaoFee = 0.0;
      });
      return;
    }
    
    setState(() {
      _isLoadingTaobaoFee = true;
      _taobaoFeeErrorMsg = null;
    });
    
    try {
      final response = await HttpUtil.post(
        fee,
        data: {
          "productFeeDTOs": selectedItems,
          "houseAddressId": 1 // 默认仓库地址ID
        },
      );
      
      if (response.data['code'] == 200) {
        // 根据新的返回格式处理运费
        List<dynamic> feeData = response.data['data'] ?? [];
        double totalPostFee = 0.0;
        Map<String, double> itemFees = {};
        
        print('运费API返回的原始数据: $feeData');
        
        // 遍历所有商品的运费信息
        for (var item in feeData) {
          // 注意：API返回的字段名是item_id而不是itemId
          if (item != null && item['item_id'] != null) {
            // 使用postFeeKRW字段作为韩元运费
            double postFeeKRW = double.tryParse(item['postFeeKRW'].toString()) ?? 0.0;
            totalPostFee += postFeeKRW;
            String itemIdStr = item['item_id'].toString();
            itemFees[itemIdStr] = postFeeKRW;
            print('设置商品ID: $itemIdStr 的韩元运费: $postFeeKRW');
            

          } else {

          }
        }
        
        setState(() {
          _taobaoFee = totalPostFee;
          _itemTaobaoFees = itemFees;
          
          // 将运费直接关联到商品对象中
          for (var shop in _shops) {
            for (var item in shop.items) {
              String itemIdStr = item.productId.toString();
              if (itemFees.containsKey(itemIdStr)) {
                // 不管是否选中，都设置运费，因为后面可能会选中
                item.taobaoFee = itemFees[itemIdStr]!;
              }
            }
          }
        });
      } else {
        throw Exception(response.data['msg'] ?? '获取淘宝运费失败');
      }
    } catch (e) {
      setState(() {
        _taobaoFeeErrorMsg = e.toString().replaceAll('Exception: ', '');
        // 发生错误时，运费设置为0
        _taobaoFee = 0.0;
      });
      debugPrint('淘宝运费接口请求失败: $e');
    } finally {
      setState(() {
        _isLoadingTaobaoFee = false;
      });
    }
  }
  
  // 新增：获取运费列表接口
  Future<void> _fetchShippingFeeList() async {
    if (_token == null || _token!.isEmpty) {
      setState(() {
        _feeErrorMsg = AppLocalizations.of(context)?.translate('please_login_first') ?? '请先登录';
      });
      return;
    }

    setState(() {
      _isLoadingFee = true;
      _feeErrorMsg = null;
    });

    try {
      final response = await HttpUtil.get(feelist);
      if (response.data['code'] == 200) {
        List<dynamic> rawData = response.data['data'] ?? [];
        // 过滤类型为重量（type: "1"）的运费规则
        List<Map<String, dynamic>> weightFeeList = rawData
            .where((item) => item['type'] == "1")
            .map((item) => item as Map<String, dynamic>)
            .toList();

        setState(() {
          _shippingFeeList = weightFeeList;
        });
      } else {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('fetch_fee_failed') ?? '获取运费数据失败');
      }
    } catch (e) {
      setState(() {
        _feeErrorMsg = e.toString().replaceAll('Exception: ', '');
      });
      debugPrint('运费接口请求失败: $e');
    } finally {
      setState(() {
        _isLoadingFee = false;
      });
    }
  }

  Future<void> _loadCollectList() async {
    if (_isCollectLoading) return;
    if (_token == null || _token!.isEmpty) {
      setState(() {
        _isCollectLoading = false;
        _errorMsg = AppLocalizations.of(context)?.translate('please_login_first') ?? "请先登录";
      });
      return;
    }
    setState(() {
      _currentCollectPage = 1;
      _isCollectLoading = true;
      _hasMoreCollect = true;
      _collectItems.clear();
    });
    try {
      final response = await HttpUtil.get(
        collectlist,
        queryParameters: {
          'pageSize': _collectPageSize,
          'pageNum': _currentCollectPage,
        },
      );
      if (response.data['code'] == 200) {
        List<dynamic> rawItems = response.data['rows'] ?? [];
        List<CollectItem> items =
            rawItems.map((json) => CollectItem.fromJson(json)).toList();
        setState(() {
          _collectItems = items;
          _hasMoreCollect = items.length == _collectPageSize;
        });
      } else {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('load_collect_failed') ?? '加载收藏列表失败');
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isCollectLoading = false;
      });
    }
  }

  Future<void> _loadMoreCollectList() async {
    if (_isCollectLoading || !_hasMoreCollect) return;
    setState(() {
      _currentCollectPage++;
      _isCollectLoading = true;
    });
    try {
      final response = await HttpUtil.get(
        collectlist,
        queryParameters: {
          'pageSize': _collectPageSize,
          'pageNum': _currentCollectPage,
        },
      );
      if (response.data['code'] == 200) {
        List<dynamic> rawItems = response.data['rows'] ?? [];
        List<CollectItem> items =
            rawItems.map((json) => CollectItem.fromJson(json)).toList();
        setState(() {
          _collectItems.addAll(items);
          _hasMoreCollect = items.length == _collectPageSize;
        });
      } else {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('load_more_collect_failed') ?? '加载更多收藏列表失败');
      }
    } catch (e) {
      debugPrint('加载更多收藏列表失败: $e');
    } finally {
      setState(() {
        _isCollectLoading = false;
      });
    }
  }

  Future<void> _updateQuantityApi(CartItem item, int change) async {
    if (_token == null || _token!.isEmpty) {
      _showSnackBar(AppLocalizations.of(context)?.translate('please_login_first') ?? '请先登录');
      return;
    }
    if (_memberId == null) {
      _showSnackBar(AppLocalizations.of(context)?.translate('member_info_missing') ?? '会员信息缺失');
      return;
    }

    final int newQuantity = item.num + change;
    if (newQuantity < 1) {
      _showSnackBar(AppLocalizations.of(context)?.translate('quantity_cannot_less_1') ?? '数量不能小于1');
      return;
    }

    final int oldQuantity = item.num;

    setState(() {
      for (var shop in _shops) {
        for (var cartItem in shop.items) {
          if (cartItem.cartId == item.cartId) {
            cartItem.num = newQuantity;
            break;
          }
        }
      }
    });

    try {
      final params = {
        "cartId": item.cartId,
        "memberId": _memberId!,
        "productId": item.productId,
        "num": newQuantity,
        "secId": item.secId,
      };

      final response = await HttpUtil.put(
        unpedcart,
        data: params,
      );

      if (response.data['code'] != 200) {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('update_quantity_failed') ?? '修改数量失败');
      }
    } catch (e) {
      setState(() {
        for (var shop in _shops) {
          for (var cartItem in shop.items) {
            if (cartItem.cartId == item.cartId) {
              cartItem.num = oldQuantity;
              break;
            }
          }
        }
      });
      _showSnackBar('${AppLocalizations.of(context)?.translate('update_failed') ?? '修改失败'}: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _deleteCartItem(Shop shop, CartItem item) async {
    if (_token == null || _token!.isEmpty) {
      _showSnackBar(AppLocalizations.of(context)?.translate('please_login_first') ?? '请先登录');
      setState(() => _itemOffset[item.cartId] = 0.0);
      return;
    }

    try {
      final String deleteUrl = revmecartlist.replaceAll(
        RegExp(r'\{cartIds\}'),
        item.cartId.toString(),
      );
      final response = await HttpUtil.del(deleteUrl);

      if (response.data['code'] == 200) {
        setState(() {
          shop.items.remove(item);
          _itemOffset.remove(item.cartId);
          if (shop.items.isEmpty) {
            _shops.remove(shop);
          }
        });
        _showSnackBar(AppLocalizations.of(context)?.translate('delete_success') ?? '删除成功');
      } else {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('delete_failed') ?? '删除失败');
      }
    } catch (e) {
      setState(() => _itemOffset[item.cartId] = 0.0);
      _showSnackBar('${AppLocalizations.of(context)?.translate('delete_failed') ?? '删除失败'}: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
  
  // 修改：始终显示韩元价格
  (String formattedPrice, String currencySymbol) _getPriceByLanguage(double price) {
    // 始终显示韩元价格，移除语言判断
    // 直接将价格转换为整数，避免任何四舍五入
    String formatted = price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return (formatted, '₩'); // 使用韩元符号
  }

  void _updateQuantity(CartItem item, int change) {
    _updateQuantityApi(item, change);
  }

  /// 检查订单金额是否超过最大订单限额
  void _checkMaxOrderLimit() async {
    try {
      // 获取本地存储的最大订单限额
      final prefs = await SharedPreferences.getInstance();
      String? maxLimitStr = prefs.getString('maxOrderLimit');
      
      if (maxLimitStr == null || maxLimitStr.isEmpty) {
        // 如果没有存储最大限额，继续流程
        setState(() => _showShippingInfo = true);
        return;
      }
      
      // 解析最大订单限额
      double maxLimit = double.tryParse(maxLimitStr) ?? 0;
      if (maxLimit <= 0) {
        // 如果最大限额无效，继续流程
        setState(() => _showShippingInfo = true);
        return;
      }
      
      // 计算当前订单金额
      double totalPrice = _calculateSummary().$1;
      
      // 比较订单金额和最大限额
      if (totalPrice > maxLimit) {
        // 如果超过限额，显示提示信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "订单金额超过最大限额 $maxLimit",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // 如果未超过限额，继续流程
      setState(() => _showShippingInfo = true);
    } catch (e) {
      // 异常处理
      print('检查最大订单限额异常：$e');
      // 异常情况下继续流程
      setState(() => _showShippingInfo = true);
    }
  }

  (double totalPrice, int totalQuantity, int totalTypes) _calculateSummary() {
    double price = 0;
    int quantity = 0;
    double totalTaobaoFee = 0;
    // 使用Set来存储已选中的不同商品种类（基于productId和secId的组合）
    Set<String> uniqueProducts = {};
    
    for (var shop in _shops) {
      for (var item in shop.items) {
        if (item.isSelected) {
          // 优先使用会员韩元价，如果会员价存在且大于0，则使用会员价，否则使用普通韩元价格
          double priceToUse = (item.productPlusPriceKRW != null && item.productPlusPriceKRW! > 0) ? item.productPlusPriceKRW! : item.productPriceKRW;
          price += priceToUse * item.num;
          quantity += item.num;
          // 累加每个商品的单独淘宝运费（注意：运费可能仍然是人民币，需要转换为韩元？或者直接使用API返回的运费韩元值？
          // 这里暂时保持原逻辑，因为用户没有特别说明运费的处理方式
          totalTaobaoFee += _itemTaobaoFees[item.productId.toString()] ?? 0.0;
          // 使用productId和secId的组合作为唯一标识，确保不同规格的商品被计为不同种类
          uniqueProducts.add('${item.productId}_${item.secId}');
        }
      }
    }
    
    // 加上商品的单独淘宝运费
    price += totalTaobaoFee;
    
    // Set的大小即为不同商品种类的数量
    // 处理浮点数精度问题，直接取整避免四舍五入
    double finalPrice = price.floorToDouble();
    return (finalPrice, quantity, uniqueProducts.length);
  }
  
  // 收集选中的商品数据，格式化为Payment页面需要的数据结构
  List<Map<String, dynamic>> _getSelectedProducts() {
    List<Map<String, dynamic>> result = [];
    Map<String, List<Map<String, dynamic>>> shopItemsMap = {};
    
    // 按店铺分组收集选中的商品
    for (var shop in _shops) {
      for (var item in shop.items) {
        if (item.isSelected) {
          if (!shopItemsMap.containsKey(shop.shopName)) {
            shopItemsMap[shop.shopName] = [];
          }
          
          // 直接使用商品对象中的taobaoFee字段
          
          var productData = {
            'createBy': 'bms',
            'createTime': DateTime.now().toString(),
            'updateBy': 'bms',
            'updateTime': DateTime.now().toString(),
            'remark': null,
            'cartId': item.cartId,
            'memberId': item.memberId,
            'memberName': 'bms',
            'productId': item.productId,
            'productName': item.productName,
            'shopId': item.shopId , // 使用商品实际的店铺ID
            'shopName': shop.shopName,
            'secId': item.secId,
            'secName': item.secName,
            'wangwangUrl': '',
            'productUrl': item.productUrl,
            'totalPrice': double.parse((item.productPriceKRW * item.num).toStringAsFixed(2)),
            'totalPlusPrice': double.parse((item.productPlusPriceKRW! * item.num).toStringAsFixed(2)),
            'num': item.num,
            'productPrice': item.productPriceKRW,
            'productPlusPrice': item.productPlusPriceKRW,
            'minNum': 0,
            'sec': item.sec,
            'wangwangTalkUrl': '',
            'productNameCn': item.productName, // 使用现有productName作为中文名
            'productNameEn': item.productName, // 使用现有productName作为英文名
            'selfSupport': item.selfSupport,
            'currencyKr': null,
            'currencyUsd': null,
            'delFlag': '0',
            'orderId': null,
            'orderNo': null,
            'taobaofee': item.taobaoFee // 直接使用商品对象中的运费
          };
          
          // 打印选中的商品数据
          print('选中的商品数据: $productData');
          
          shopItemsMap[shop.shopName]!.add(productData);
        }
      }
    }
    
    // 打印总价计算相关数据
    var summary = _calculateSummary();
    
    // 转换为最终的数据结构
    shopItemsMap.forEach((shopName, items) {
      result.add({
        'shopName': shopName,
        'cartList': items
      });
    });
    
    // 打印最终返回的数据结构
    
    return result;
  }

  void _toggleShopSelection(Shop shop) {
    setState(() {
      shop.isAllSelected = !shop.isAllSelected;
      for (var item in shop.items) {
        item.isSelected = shop.isAllSelected;
      }
    });
    
    // 选中状态改变后，获取淘宝运费
    _fetchTaobaoFee();
  }

  void _toggleItemSelection(Shop shop, CartItem item) {
    setState(() {
      item.isSelected = !item.isSelected;
      shop.isAllSelected = shop.items.every((i) => i.isSelected);
    });
    
    // 选中状态改变后，获取淘宝运费
    _fetchTaobaoFee();
  }

  Widget _buildDeleteAction(CartItem item, Shop shop) {
    return SizedBox(
      width: 120,
      child: GestureDetector(
        onTap: () => _deleteCartItem(shop, item),
        child: Container(
          color: const Color(0xFFDC3545),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete, color: Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)?.translate('delete') ?? '删除',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(Shop shop, CartItem item) {
    final String imageUrl = item.productUrl.startsWith('http')
        ? item.productUrl
        : 'https:${item.productUrl}';
    final double maxOffset = 120;

    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: _buildDeleteAction(item, shop),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            double newOffset = _itemOffset[item.cartId]! + details.delta.dx;
            if (newOffset > 0) newOffset = 0;
            if (newOffset < -maxOffset) newOffset = -maxOffset;
            setState(() => _itemOffset[item.cartId] = newOffset);
          },
          onHorizontalDragEnd: (details) {
            if (_itemOffset[item.cartId]! < -maxOffset / 2) {
              setState(() => _itemOffset[item.cartId] = -maxOffset);
            } else {
              setState(() => _itemOffset[item.cartId] = 0.0);
            }
          },
          child: Transform.translate(
            offset: Offset(_itemOffset[item.cartId]!, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: item.isSelected,
                    onChanged: (value) => _toggleItemSelection(shop, item),
                    activeColor: Colors.blue,
                    shape: const CircleBorder(),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.secName,
                                    style: const TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // 使用新的方法始终显示韩元价格
                                  Builder(builder: (context) {
                                    // 始终使用韩元价格字段
                                    final double price = item.productPriceKRW;
                                    
                                    final (normalFormattedPrice, currencySymbol) = _getPriceByLanguage(price);
                                    
                                    // 检查是否有会员价并且会员价小于普通价格
                                    if (item.productPlusPriceKRW != null && 
                                        item.productPlusPriceKRW! > 0 && 
                                        item.productPlusPriceKRW! < price) {
                                      final double plusPrice = item.productPlusPriceKRW!;
                                      final (plusFormattedPrice, _) = _getPriceByLanguage(plusPrice);
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$currencySymbol $plusFormattedPrice",
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            "$currencySymbol $normalFormattedPrice",
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      // 只显示普通价格
                                      return Text(
                                        "$currencySymbol $normalFormattedPrice",
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    }
                                  }),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.remove,
                                      color: Colors.black87,
                                      size: 16,
                                    ),
                                    onPressed: () => _updateQuantity(item, -1),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    "${item.num}",
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.black87,
                                      size: 16,
                                    ),
                                    onPressed: () => _updateQuantity(item, 1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToProductDetail(CollectItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetails(id: item.productId.toString()),
      ),
    );
  }

  Widget _buildCollectItem(CollectItem item) {
    return GestureDetector(
      onTap: () => _navigateToProductDetail(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      item.productUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productNameCn,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.productPrice != null
                              ? "${AppLocalizations.of(context)?.translate('cny') ?? '¥'}${item.productPrice!.toStringAsFixed(2)}"
                              : AppLocalizations.of(context)?.translate('no_price') ?? "暂无价格",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.shopName,
                          style: const TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0xFFEEEEEE),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    if (_currentTab == 0) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator(color: Colors.blue));
      }

      if (_errorMsg != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _initTokenAndMemberId(),
                child: Text(
                  AppLocalizations.of(context)?.translate('retry') ?? '重试',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      }

      if (_shops.isEmpty || _shops.every((shop) => shop.items.isEmpty)) {
        return Center(
          child: Text(
            AppLocalizations.of(context)?.translate('cart_empty') ?? '购物车为空',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _shops.length,
        itemBuilder: (context, shopIndex) {
          final shop = _shops[shopIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Checkbox(
                        value: shop.isAllSelected,
                        onChanged: (value) => _toggleShopSelection(shop),
                        activeColor: Colors.blue,
                        shape: const CircleBorder(),
                      ),
                      Text(
                        shop.shopName,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // TextButton(
                      //   onPressed: () {},
                      //   style: TextButton.styleFrom(
                      //     foregroundColor: Colors.grey,
                      //     padding: EdgeInsets.zero,
                      //   ),
                      //   child: Text(
                      //     AppLocalizations.of(context)?.translate('delete') ?? '删除',
                      //     style: const TextStyle(fontSize: 14),
                      //   ),
                      // ),
                    ],
                  ),
                ),
                Column(
                  children: shop.items.map((item) => _buildCartItem(shop, item)).toList(),
                ),
              ],
            ),
          );
        },
      );
    } else {
      if (_isCollectLoading && _collectItems.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: Colors.blue));
      }
      if (_errorMsg != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _loadCollectList(),
                child: Text(
                  AppLocalizations.of(context)?.translate('retry') ?? '重试',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      }
      if (_collectItems.isEmpty) {
        return Center(
          child: Text(
            AppLocalizations.of(context)?.translate('favorites_empty') ?? '收藏列表为空',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        );
      }
      return ListView.builder(
        controller: _collectScrollController,
        padding: const EdgeInsets.only(top: 8),
        itemCount: _collectItems.length + (_hasMoreCollect ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _collectItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final item = _collectItems[index];
          return _buildCollectItem(item);
        },
      );
    }
  }

  // 弹窗1：配送说明（按钮上下排列，保留原始文字）
  Widget _buildShippingInfoDialog() {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "COUZIK捆绑海外代购服务\n订购的订单内所有商品入库后\n会称重所有的商品，计算国际运费。\n\n代理手续费与商品价值结算（1次）后\n国际运费结算（2次）完成后，货物才会出库。\n\n预期运费只是预期，与实际运费有差距",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Column(// 按钮上下排列
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () async {
                  // 点击时加载运费数据
                  await _fetchShippingFeeList();
                  setState(() {
                    _showShippingFeeList = true;
                    _showShippingInfo = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange,
                  child: const Text(
                    "配送费用金额确认",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDisclaimer = true;
                    _showShippingInfo = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.green,
                  child: const Text(
                    "确认及下页",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 弹窗2：运费列表（替换为接口获取的真实数据）
Widget _buildShippingFeeListDialog() {
  return AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoadingFee)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_feeErrorMsg != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _feeErrorMsg!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _fetchShippingFeeList(),
                child: const Text('重新加载'),
              ),
            ],
          )
        else if (_shippingFeeList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '暂无重量相关运费数据',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          )
        else
          DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("重量")),
              DataColumn(label: Text("运费")),
            ],
            rows: _shippingFeeList.map((fee) {
              // 处理单位：1→g，2→kg
              String unitText = fee['unit'] == "1" ? "g" : "kg";
              // 左边显示：具体重量值 + 单位（如20g、1.0kg）
              String weightText = "${fee['standardMax']} $unitText";
              // 使用新的方法根据语言动态显示运费
              double feeValue = (fee['fee'] ?? 0).toDouble();
              return DataRow(cells: [
                DataCell(Text(weightText)),
                DataCell(Builder(builder: (context) {
                  final (formattedPrice, currencySymbol) = _getPriceByLanguage(feeValue);
                  return Text("$currencySymbol $formattedPrice");
                })),
              ]);
            }).toList(),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _showShippingFeeList = false;
              _showShippingInfo = true;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey,
            child: const Text(
              "返回",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

  // 弹窗3：免责声明（保留原始文字）
  Widget _buildDisclaimerDialog() {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "包含侵权知识产权，不可通关商品、破损危险较高的商品时订单可能会部分或全部取消。\n\n管理者对未认知知识产权商品 通关中发生的扣押/销毁的责任由代理申请人承担。\n\n订购总额超过150美元时，可分多次进行或可能会根据申报金额征收关税。\n\n因报关信息不一致导致的报关滞留 COUZIK不负相关责任",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => _showDisclaimer = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("已同意并完成付款流程"),
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                // 收集选中的商品数据，每个商品对象中已包含各自的淘宝运费
                List<Map<String, dynamic>> selectedProducts = _getSelectedProducts();
                
                print('传递给支付页面的商品数据: $selectedProducts');
                
                // 跳转到支付页面，只传递商品数据
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PaymentPage(selectedProducts: selectedProducts)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.green,
                child: const Text(
                  "同意及付款",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (totalPrice, totalQuantity, totalTypes) = _calculateSummary();

    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // 标题栏布局（保留原有国际化）
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      AppLocalizations.of(context)?.translate('my_cart') ?? '我的购物车',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selfSupport = 1;
                            });
                            _fetchCartList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selfSupport == 1 ? Colors.blue.shade100 : Colors.grey.shade200,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.translate('direct_buy_product') ?? '直购商品',
                              style: TextStyle(color: _selfSupport == 1 ? Colors.blue : Colors.grey, fontSize: 14),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selfSupport = 2;
                            });
                            _fetchCartList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selfSupport == 2 ? Colors.blue.shade100 : Colors.grey.shade200,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)?.translate('recommended_product') ?? '推荐商品',
                              style: TextStyle(color: _selfSupport == 2 ? Colors.blue : Colors.grey, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 购物车/收藏夹标签栏（保留原有国际化）
              Container(
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _currentTab == 0 ? Colors.blue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_cart,
                                color: _currentTab == 0 ? Colors.blue : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)?.translate('shopping_cart') ?? '购物车',
                                style: TextStyle(
                                  color: _currentTab == 0 ? Colors.blue : Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _currentTab = 1);
                          if (_collectItems.isEmpty) _loadCollectList();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _currentTab == 1 ? Colors.blue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.favorite_border,
                                color: _currentTab == 1 ? Colors.blue : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)?.translate('favorites') ?? '收藏夹',
                                style: TextStyle(
                                  color: _currentTab == 1 ? Colors.blue : Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildCartContent()),
              // 底部结算栏（保留原有国际化）
              if (_currentTab == 0 && !_isLoading && _errorMsg == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.translate('selected_products_info')
                                    ?.replaceAll('\${totalTypes}', totalTypes.toString())
                                    .replaceAll('\${totalQuantity}', totalQuantity.toString()) ??
                                "选中的商品:${totalTypes}种类 总数量:${totalQuantity}个",
                            style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                          ),
                          // 使用新的方法根据语言动态显示总价
                          Builder(builder: (context) {
                            final (formattedPrice, currencySymbol) = _getPriceByLanguage(totalPrice);
                            return Text(
                              "$currencySymbol $formattedPrice",
                              style: const TextStyle(
                                color: Color.fromARGB(221, 4, 206, 18),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }),
                          // if (totalQuantity > 0)
                          //   const Text(
                          //     "예상운임 : 10,000원",
                          //     style: TextStyle(color: Color.fromARGB(255, 255, 0, 0), fontSize: 14),
                          //   ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 140,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: totalQuantity > 0
                              ? _checkMaxOrderLimit
                              : null,
                          child: Text(
                            AppLocalizations.of(context)?.translate('buy_now') ?? '购买',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // 新功能：点击外部关闭弹窗的遮罩
          if (_showShippingInfo || _showShippingFeeList || _showDisclaimer)
            GestureDetector(
              onTap: () => setState(() {
                _showShippingInfo = false;
                _showShippingFeeList = false;
                _showDisclaimer = false;
              }),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          // 新功能：弹窗（保留原始文字）
          if (_showShippingInfo) _buildShippingInfoDialog(),
          if (_showShippingFeeList) _buildShippingFeeListDialog(),
          if (_showDisclaimer) _buildDisclaimerDialog(),
        ],
      ),
    );
  }
}