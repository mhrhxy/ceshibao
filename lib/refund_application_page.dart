import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:dio/src/multipart_file.dart'; // 用于MediaType
import 'package:flutter/foundation.dart'; // 用于判断平台类型
import 'dingbudaohang.dart';
import '../utils/http_util.dart';
import '../config/service_url.dart';

class RefundApplicationPage extends StatefulWidget {
  final String orderId;
  final String refundType; // 'return' 表示退货退款, 'refund' 表示仅退款
  final dynamic order; // 完整的订单对象

  const RefundApplicationPage({
    super.key,
    required this.orderId,
    required this.refundType,
    this.order,
  });

  @override
  State<RefundApplicationPage> createState() => _RefundApplicationPageState();
}

class _RefundApplicationPageState extends State<RefundApplicationPage> {
  // 退款类型相关变量
  String _currentRefundType = '1'; // 1仅退款(无需退货) 2仅退货退款 3仅换货 4仅补寄
  final List<Map<String, dynamic>> _refundTypeOptions = [
    {'value': '1', 'label': '仅退款', 'title': '申请退款'},
    {'value': '2', 'label': '仅部分退款', 'title': '申请退款'},
    {'value': '3', 'label': '退货退款', 'title': '申请退货退款'},
    {'value': '4', 'label': '仅部分退货退款', 'title': '申请退货退款'},
  ];

  @override
  void initState() {
    super.initState();
    // 根据上一个页面传递的refundType设置默认值
    if (widget.refundType == 'return') {
      _currentRefundType = '3'; // 默认选择退货退款
    } else {
      _currentRefundType = '1'; // 默认选择仅退款
    }
    
    // 初始化退款金额为订单的商品总金额
    if (widget.order != null) {
      // 检查widget.order是Map还是OrderData对象
      double productAllPrice = 0.0;
      if (widget.order is Map) {
        productAllPrice = (widget.order as Map)['productAllPrice']?.toDouble() ?? 0.0;
      } else {
        // 假设OrderData类有productAllPrice属性
        try {
          productAllPrice = widget.order.productAllPrice?.toDouble() ?? 0.0;
        } catch (e) {
          print('获取productAllPrice属性失败: $e');
        }
      }
      
      // 初始设置为0，后面会在_fetchOrderProducts中更新为remainingAmount总和
      _maxRefundAmount = 0.0;
      _refundAmount = '0.00';
      _amountController.text = _refundAmount;
    }
    
    // 获取订单商品列表
    _fetchOrderProducts();
  }
  
  // 获取订单商品列表
  Future<void> _fetchOrderProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });
    
    try {
      // 使用新接口，通过子订单ID查询子订单信息
      String apiUrl = refundSearchProductUrl.replaceAll('{orderId}', widget.orderId);
      var response = await HttpUtil.get(apiUrl);
      
      if (response.statusCode == 200) {
        setState(() {
          var responseData = response.data;
          if (responseData['code'] == 200) {
            var data = responseData['data'];
            
            // 获取子订单信息（包含可退款金额）
            var orderInfo = data['orderInfo'] ?? {};
            
            // 从orderInfo获取可退款金额
            double remainingAmount = 0.0;
            try {
              remainingAmount = double.parse(orderInfo['remainingAmount']?.toString() ?? '0');
            } catch (e) {
              print('解析remainingAmount失败: $e');
            }
            
            // 获取商品列表
            var orderProductInfoList = data['orderProductInfoList'] as List? ?? [];
            
            // 解析商品数据
            _orderProducts = orderProductInfoList.map((item) {
              // 处理图片URL中的反引号
              var productInfo = item as Map<String, dynamic>;
              if (productInfo['imgUrl'] != null) {
                productInfo['imgUrl'] = productInfo['imgUrl'].toString().replaceAll('`', '').trim();
              }
              return productInfo;
            }).toList();
            
            // 为每个商品设置独立的退款数量和最大可退款数量
            _refundQuantities = {};
            _maxQuantities = {};
            for (int i = 0; i < _orderProducts.length; i++) {
              // 从商品的remainingNum获取可退款数量
              int remainingNum = 0;
              try {
                remainingNum = int.parse(_orderProducts[i]['remainingNum']?.toString() ?? '0');
              } catch (e) {
                print('解析remainingNum失败: $e');
              }
              _maxQuantities[i] = remainingNum;
              _refundQuantities[i] = remainingNum > 0 ? remainingNum : 0; // 默认退全部
            }
            
            // 设置最大可退款金额（从orderInfo.remainingAmount获取）
            _maxRefundAmount = remainingAmount;
            
            // 更新默认退款金额为最大可退款金额
            _refundAmount = _maxRefundAmount.toStringAsFixed(2);
            _amountController.text = _refundAmount;
          }
        });
      }
    } catch (e) {
      print('获取订单商品列表失败: $e');
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }
  
  // 验证并更新退款金额
  void _validateAndUpdateRefundAmount(String value) {
    if (value.isEmpty) {
      _refundAmount = '0.00';
      return;
    }
    
    double enteredAmount = double.tryParse(value) ?? 0.00;
    
    if (enteredAmount > _maxRefundAmount) {
      // 超过最大金额，设置为最大金额并提示
      enteredAmount = _maxRefundAmount;
      _refundAmount = enteredAmount.toStringAsFixed(2);
      _amountController.text = _refundAmount;
      
      // 显示提示信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('不能超过最大退款金额: ¥$_maxRefundAmount'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _refundAmount = enteredAmount.toStringAsFixed(2);
    }
  }

  // 根据退款类型获取页面标题
  String getPageTitle() {
    var selectedOption = _refundTypeOptions.firstWhere(
      (option) => option['value'] == _currentRefundType,
      orElse: () => _refundTypeOptions[0]
    );
    return selectedOption['title'];
  }

  // 金额编辑相关变量
  bool _isEditingAmount = false;
  String _refundAmount = '0.00';
  final TextEditingController _amountController = TextEditingController();
  double _maxRefundAmount = 0.00; // 最大可退款金额
  
  // 数量选择相关变量
  Map<int, int> _refundQuantities = {}; // 存储每个商品的退款数量，key为商品索引
  Map<int, int> _maxQuantities = {}; // 存储每个商品的最大可退款数量，key为商品索引
  
  // 图片上传相关变量
  final ImagePicker _picker = ImagePicker();
  List<String> _uploadedImages = []; // 存储上传后的图片URL
  bool get _isWeb => kIsWeb;
  
  // 构建规格信息显示
  Widget _buildSpecifications(dynamic product) {
    // 尝试获取不同格式的规格信息
    String specifications = '';
    
    // 优先处理SKU JSON格式
    if ((product['sku'] ?? '').isNotEmpty) {
      try {
        String skuJson = product['sku'];
        Map<String, dynamic> skuData = json.decode(skuJson);
        
        // 从properties中提取规格信息
        if (skuData.containsKey('properties') && skuData['properties'] is List) {
          List<dynamic> properties = skuData['properties'];
          List<String> specList = [];
          
          for (var prop in properties) {
            if (prop is Map && 
                prop.containsKey('value_name') && 
                prop['value_name'] != null) {
              specList.add(prop['value_name'].toString());
            }
          }
          
          if (specList.isNotEmpty) {
            specifications = specList.join(' ');
          }
        }
      } catch (e) {
        print('解析SKU JSON失败: $e');
        // 解析失败，尝试其他字段
      }
    }
    
    // 如果SKU解析失败或没有SKU信息，尝试其他规格字段
    if (specifications.isEmpty) {
      specifications = product['productAttr'] ?? 
                      product['spec'] ?? 
                      '';
    }
    
    // 如果有规格信息则显示
    if (specifications.isNotEmpty) {
      return Column(
        children: [
          Text(
            specifications,
            style: TextStyle(
              fontSize: 12.sp,
              color: Color(0xFF999999),
            ),
          ),
          SizedBox(height: 8.h),
        ],
      );
    } else {
      // 没有规格信息则不显示
      return SizedBox.shrink();
    }
  }
  
  // 订单商品列表
  List<dynamic> _orderProducts = [];
  bool _isLoadingProducts = false;

  // 申请说明相关变量
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false; // 提交状态

  // 提交退款申请
  Future<void> _submitRefundApplication() async {
    // 验证必填项
    if (_orderProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('没有可退款的商品'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (double.parse(_refundAmount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('退款金额必须大于0'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请填写退款说明'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 获取订单信息
      print('widget.order: ${widget.order}');
      print('widget.order.runtimeType: ${widget.order.runtimeType}');
      int orderId = widget.orderId != null ? int.tryParse(widget.orderId) ?? 0 : 0;
      String orderOriginNo = '';
      String outerPurchaseId = '';
      String selfSupport = '1'; // 默认值
      
      if (widget.order != null) {
        if (widget.order is Map) {
          // 处理Map类型
          orderOriginNo = widget.order['orderOriginNo']?.toString() ?? '';
          outerPurchaseId = widget.order['outerPurchaseId']?.toString() ?? '';
          selfSupport = widget.order['selfSupport']?.toString() ?? '1';
        } else {
          // 处理OrderData实例
          try {
            orderOriginNo = (widget.order as dynamic).orderOriginNo ?? '';
            outerPurchaseId = (widget.order as dynamic).outerPurchaseId ?? '';
          } catch (e) {
            print('从OrderData获取属性失败: $e');
          }
        }
      }
      
      // 计算总退款数量（只统计数量大于0的商品）
      int totalRefundNum = _refundQuantities.values
          .where((quantity) => quantity > 0)
          .fold(0, (sum, quantity) => sum + quantity);
      
      // 整合退款申请数据
      Map<String, dynamic> refundInfo = {
        "orderId": orderId,
        "refundPrice": double.parse(_refundAmount),
        "refundImages": _uploadedImages.join(','), // 图片逗号分隔
        "refundDesc": _descriptionController.text.trim(),
        "refundType": _currentRefundType,
        "orderOriginNo": orderOriginNo, // 原始订单编号
        "outerPurchaseId": outerPurchaseId, // isv采购id
        "selfSupport": selfSupport, // 是否自营（1否 2是）
        "refundNum": totalRefundNum // 总退款数量
      };

      // 整合商品信息列表
      List<Map<String, dynamic>> refundProductInfoList = [];
      for (var product in _orderProducts) {
        int index = _orderProducts.indexOf(product);
        int refundNum = _refundQuantities[index] ?? 1;
        
        // 只添加退款数量大于0的商品
        if (refundNum > 0) {
          Map<String, dynamic> productInfo = {
            "skuId": product['skuId'] ?? 0,
            "orderProductId": product['orderProductId'] ?? 0,
            "orderId": orderId,
            "refundType": _currentRefundType,
            "refundStatus": "1", // 申请退款
            "selfSupport": product['selfSupport']?.toString() ?? selfSupport,
             // 将总价estimateAmount除以原始数量得到单价，再乘以退款数量得到正确的退款价格
             // 自营商品(selfSupport=2)直接用price作为单价
             "refundPrice": () {
               // selfSupport: 1=否（非自营），2=是（自营）
               bool isSelfSupport = product['selfSupport'] == 2;
               if (isSelfSupport) {
                 // 自营商品直接用price乘以退款数量
                 double unitPrice = product['price'] != null ? double.parse(product['price'].toString()) : 0.0;
                 return unitPrice * refundNum;
               } else {
                 // 非自营商品按原逻辑计算
                 int originalQuantity = int.tryParse(product['quantity']?.toString() ?? '1') ?? 1;
                 double totalPrice = (product['estimateAmount'] != null ? double.parse(product['estimateAmount'].toString()) : 0.0);
                 double unitPrice = originalQuantity > 0 ? totalPrice / originalQuantity : 0.0;
                 return unitPrice * refundNum;
               }
             }(),
            "purchaseOrderLineId": product['purchaseOrderId']?.toString() ?? '', // 采购子订单id
            "productId": product['itemId']?.toString() ?? '', // 商品ID 对应淘宝商品ID
            "sku": product['sku'] ?? "",
            "refundNum": refundNum,
            "refundImages": product['imgUrl'], 
            "productNameCn": product['titleCn']?.toString() ?? '', // 商品名称中文
            "productNameKr": product['title']?.toString() ?? '', // 商品名称韩文
            "productNameEn": product['titleEn']?.toString() ?? '' // 商品名称英文
          };
          refundProductInfoList.add(productInfo);
        }
      }

      // 构建完整请求体
      Map<String, dynamic> requestBody = {
        "refundInfo": refundInfo,
        "refundProductInfoList": refundProductInfoList
      };

      // 调用API
      var response = await HttpUtil.post(applyRefundUrl, data: requestBody);

      // 处理响应
      if (response.statusCode == 200) {
        // 解析响应数据
        Map<String, dynamic> responseData = response.data;
        int code = responseData['code'] ?? 0;
        String message = responseData['msg'] ?? '未知错误';
        
        if (code == 200) {
          // 提交成功，显示提示并返回上一页
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('退款申请提交成功'),
              duration: Duration(seconds: 2),
            ),
          );

          // 返回上一页
          Navigator.pop(context);
        } else {
          // 业务处理失败
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('退款申请提交失败'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // HTTP请求失败
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('退款申请提交失败，请重试'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('提交退款申请失败，请重试'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // 重置所有已修改内容
  void _resetAllContent() {
    _isEditingAmount = false;
    // 根据当前退款类型重置默认金额
    String defaultAmount;
    if (_currentRefundType == '2' || _currentRefundType == '4') {
      // 部分退款类型，默认设置为最小退款金额1元
      defaultAmount = '1.00';
    } else {
      // 全额退款类型，默认设置为最大可退金额
      defaultAmount = _maxRefundAmount.toStringAsFixed(2);
    }
    _refundAmount = defaultAmount;
    // 重置所有商品的退款数量，考虑remainingNum限制
    for (int i = 0; i < _orderProducts.length; i++) {
      int maxQuantity = _maxQuantities[i] ?? 0;
      _refundQuantities[i] = maxQuantity > 0 ? 1 : 0;
    }
    _amountController.clear();
    _descriptionController.clear();
    _uploadedImages.clear();
  }

  // 图片选择和上传方法
  Future<void> _pickImage() async {
    try {
      // 选择图片
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 压缩图片质量
      );

      if (pickedFile != null) {
        setState(() {
          // 这里可以先显示一个加载指示器
        });

        FormData formData;
        if (_isWeb) {
          // Web平台处理
          final bytes = await pickedFile.readAsBytes();
          final fileName = pickedFile.name;
          final mimeType = pickedFile.mimeType ?? 'image/jpeg';
          
          formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(
              bytes,
              filename: fileName,
              contentType: DioMediaType.parse(mimeType),
            ),
          });
        } else {
          // 移动和桌面平台处理
          formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(pickedFile.path),
          });
        }
        
        var response = await HttpUtil.post(
          uploadFileUrl,
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );

        // 处理上传响应
        if (response.statusCode == 200) {
          Map<String, dynamic> responseData = response.data;
          int code = responseData['code'] ?? 0;
          
          if (code == 200) {
            // 获取图片URL
            String imageUrl = responseData['url'] ?? '';
            if (imageUrl.isNotEmpty) {
              setState(() {
                _uploadedImages.add(imageUrl);
              });
            }
          } else {
            // 上传失败
            String message = responseData['msg'] ?? '图片上传失败';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // HTTP请求失败
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('图片上传失败，请重试'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('图片选择或上传失败：$e'),
        ),
      );
    }
  }

  // 显示退款类型选择弹框
  void _showRefundTypeDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(), // 移除圆角
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 350.h, // 调整弹框高度
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和关闭按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    '请选择申请类型',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20.w, color: Color(0xFF999999)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              SizedBox(height: 24.h), // 增加上下间距
              Expanded(
                child: Column(
                  children: _refundTypeOptions.map((option) {
                    bool isSelected = _currentRefundType == option['value'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentRefundType = option['value'];
                          _resetAllContent();
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16), // 增加垂直间距
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option['label'],
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: isSelected ? Colors.red : Color(0xFF333333), // 当前选择项标红
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check, color: Colors.red, size: 20.w),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                        style:  TextStyle(
                          color: Colors.black87,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 商品信息
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _isLoadingProducts
                          ? Center(child: CircularProgressIndicator())
                          : _orderProducts.isEmpty
                              ? Center(child: Text('未获取到商品信息'))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _orderProducts.length,
                                  itemBuilder: (context, index) {
                                    var product = _orderProducts[index];
                                    return Row(
                                      children: [
                                        // 商品图片
                                        Container(
                                          width: 80.w,
                                          height: 80.h,
                                          color: Color(0xFFF4F4F4),
                                          child: product['imgUrl'] != null && product['imgUrl'].isNotEmpty
                                              ? Image.network(
                                                  product['imgUrl'],
                                                  fit: BoxFit.cover,
                                                )
                                              : Icon(Icons.image, size: 40.w, color: Color(0xFFCCCCCC)),
                                        ),
                                        SizedBox(width: 12.w),
                                        // 商品信息
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['titleCn'] ?? product['title'] ?? product['titleEn'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: Color(0xFF333333),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 8.h),
                                              // 显示规格信息，没有规格则不显示
                                              _buildSpecifications(product),
                                              // 数量选择组件
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                   Text(
                                                    '数量',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color: Color(0xFF999999),
                                                    ),
                                                  ),
                                                  // 数量选择器
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Color(0xFFEEEEEE)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        // 减少按钮
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              int currentQuantity = _refundQuantities[index] ?? 1;
                                                            int maxQuantity = _maxQuantities[index] ?? 1;
                                                            if (currentQuantity > 0) {
                                                              _refundQuantities[index] = currentQuantity - 1;
                                                              // 这里可以根据数量计算退款金额
                                                              // _updateRefundAmount();
                                                            }
                                                            });
                                                          },
                                                          child: Container(
                                                            width: 30.w,
                                                            height: 30.h,
                                                            alignment: Alignment.center,
                                                            child: Icon(
                                                              Icons.remove,
                                                              size: 16.w,
                                                              color: (_refundQuantities[index] ?? 1) <= 0 ? Color(0xFFCCCCCC) : Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ),
                                                        // 数量显示
                                                        Container(
                                                          width: 40.w,
                                                          height: 30.h,
                                                          alignment: Alignment.center,
                                                          child: Text(
                                                            '${_refundQuantities[index] ?? 1}',
                                                            style: TextStyle(
                                                              fontSize: 14.sp,
                                                              color: Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ),
                                                        // 增加按钮
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              int currentQuantity = _refundQuantities[index] ?? 1;
                                                            int maxQuantity = _maxQuantities[index] ?? 1;
                                                            if (currentQuantity < maxQuantity) {
                                                              _refundQuantities[index] = currentQuantity + 1;
                                                              // 这里可以根据数量计算退款金额
                                                              // _updateRefundAmount();
                                                            }
                                                            });
                                                          },
                                                          child: Container(
                                                            width: 30.w,
                                                            height: 30.h,
                                                            alignment: Alignment.center,
                                                            child: Icon(
                                                              Icons.add,
                                                              size: 16.w,
                                                              color: (_refundQuantities[index] ?? 1) >= (_maxQuantities[index] ?? 1) ? Color(0xFFCCCCCC) : Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                    ),
                    
                    // 申请类型
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: _showRefundTypeDialog,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text(
                              '申请类型',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Color(0xFF333333),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _refundTypeOptions.firstWhere(
                                    (option) => option['value'] == _currentRefundType,
                                    orElse: () => _refundTypeOptions[0]
                                  )['label'],
                                  style:  TextStyle(
                                    fontSize: 14.sp,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(Icons.arrow_forward_ios, size: 14.w, color: Color(0xFFCCCCCC)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 申请金额
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            '申请金额',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Color(0xFF333333),
                            ),
                          ),
                          SizedBox(height: 8.h), // 添加间距
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _isEditingAmount
                                  ? Expanded(
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(
                                          fontSize: 24.sp,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF333333),
                                        ),
                                        decoration: const InputDecoration(
                                          prefixText: '₩',
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                        autofocus: true,
                                        onChanged: (value) {
                                          _validateAndUpdateRefundAmount(value);
                                        },
                                        onSubmitted: (value) {
                                          _validateAndUpdateRefundAmount(value);
                                          setState(() {
                                            _isEditingAmount = false;
                                          });
                                        },
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isEditingAmount = true;
                                          _amountController.text = _refundAmount;
                                        });
                                      },
                                      child: Text(
                                        '¥$_refundAmount',
                                        style: TextStyle(
                                          fontSize: 24.sp, // 增大字号
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF333333), // 改为黑色
                                        ),
                                      ),
                                    ),
                              GestureDetector(
                                onTap: () {
                                  if (_isEditingAmount) {
                                    // 完成编辑时验证金额
                                    _validateAndUpdateRefundAmount(_amountController.text);
                                    setState(() {
                                      _isEditingAmount = false;
                                    });
                                  } else {
                                    setState(() {
                                      _isEditingAmount = true;
                                      _amountController.text = _refundAmount;
                                    });
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(_isEditingAmount ? Icons.check : Icons.edit, size: 14.w, color: Color(0xFF999999)),
                                    SizedBox(width: 4.w),
                                    Text(
                                      _isEditingAmount ? '完成' : '修改金额',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 申请说明和上传图片
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text(
                                '申请说明',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Color(0xFF333333),
                                ),
                              ),
                               Text(
                                '您还可以输入170字',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            width: double.infinity,
                            height: 120.h,
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFEEEEEE)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TextField(
                              controller: _descriptionController,
                              decoration:  InputDecoration(
                                hintText: '请您详细填写申请说明',
                                hintStyle: TextStyle(
                                  fontSize: 14.sp,
                                  color: Color(0xFFCCCCCC),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(12),
                              ),
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                            ),
                          ),
                          
                          SizedBox(height: 20.h),
                          
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // 已上传的图片
                              ..._uploadedImages.map((imageUrl) => Container(
                                width: 80.w,
                                height: 80.h,
                                // 移除right margin，使用Wrap的spacing控制间距
                                clipBehavior: Clip.none, // 允许内容超出容器边界
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  image: DecorationImage(
                                    image: NetworkImage(imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _uploadedImages.remove(imageUrl);
                                          });
                                        },
                                        child: Container(
                                          width: 24.w,
                                          height: 24.h,
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.w),
                                          ),
                                          child: Icon(Icons.close, size: 16.w, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                              // 添加图片按钮
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 80.w,
                                  height: 80.h,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Color(0xFFEEEEEE)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, size: 24.w, color: Color(0xFFCCCCCC)),
                                      SizedBox(height: 8.h),
                                       Text(
                                        '上传图片',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Color(0xFF999999),
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),
            
            // 提交申请按钮
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRefundApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      :  Text(
                          '提交申请',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
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