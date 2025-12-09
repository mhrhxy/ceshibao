import 'dart:convert';
import 'package:flutter/material.dart';
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
      
      _maxRefundAmount = productAllPrice;
      _refundAmount = _maxRefundAmount.toStringAsFixed(2);
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
      var params = {'orderIds': widget.orderId};
      var response = await HttpUtil.get(searchOrderProductListUrl, queryParameters: params);
      
      if (response.statusCode == 200) {
        setState(() {
          _orderProducts = response.data['data'];
          // 设置最大可退款数量为第一个商品的购买数量
          if (_orderProducts.isNotEmpty && _orderProducts[0]['quantity'] != null) {
            _maxQuantity = _orderProducts[0]['quantity'];
            _refundQuantity = 1;
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
  int _refundQuantity = 1; // 当前选择的退款数量
  int _maxQuantity = 1; // 最大可退款数量（商品购买数量）
  
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
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 8),
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
  List<String> _uploadedImages = [];

  // 重置所有已修改内容
  void _resetAllContent() {
    _isEditingAmount = false;
    _refundAmount = '19.06';
    _refundQuantity = 1;
    _amountController.clear();
    _descriptionController.clear();
    _uploadedImages.clear();
  }

  // 显示退款类型选择弹框
  void _showRefundTypeDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(), // 移除圆角
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 350, // 调整弹框高度
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和关闭按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '请选择申请类型',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF999999)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 24), // 增加上下间距
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
                                fontSize: 16,
                                color: isSelected ? Colors.red : Color(0xFF333333), // 当前选择项标红
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check, color: Colors.red, size: 20),
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
                                          width: 80,
                                          height: 80,
                                          color: Color(0xFFF4F4F4),
                                          child: product['imgUrl'] != null && product['imgUrl'].isNotEmpty
                                              ? Image.network(
                                                  product['imgUrl'],
                                                  fit: BoxFit.cover,
                                                )
                                              : const Icon(Icons.image, size: 40, color: Color(0xFFCCCCCC)),
                                        ),
                                        const SizedBox(width: 12),
                                        // 商品信息
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['titleCn'] ?? product['title'] ?? product['titleEn'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF333333),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              // 显示规格信息，没有规格则不显示
                                              _buildSpecifications(product),
                                              // 数量选择组件
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text(
                                                    '数量',
                                                    style: TextStyle(
                                                      fontSize: 12,
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
                                                              if (_refundQuantity > 1) {
                                                                _refundQuantity--;
                                                                // 这里可以根据数量计算退款金额
                                                                // _updateRefundAmount();
                                                              }
                                                            });
                                                          },
                                                          child: Container(
                                                            width: 30,
                                                            height: 30,
                                                            alignment: Alignment.center,
                                                            child: Icon(
                                                              Icons.remove,
                                                              size: 16,
                                                              color: _refundQuantity <= 1 ? Color(0xFFCCCCCC) : Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ),
                                                        // 数量显示
                                                        Container(
                                                          width: 40,
                                                          height: 30,
                                                          alignment: Alignment.center,
                                                          child: Text(
                                                            '$_refundQuantity',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Color(0xFF333333),
                                                            ),
                                                          ),
                                                        ),
                                                        // 增加按钮
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              if (_refundQuantity < _maxQuantity) {
                                                                _refundQuantity++;
                                                                // 这里可以根据数量计算退款金额
                                                                // _updateRefundAmount();
                                                              }
                                                            });
                                                          },
                                                          child: Container(
                                                            width: 30,
                                                            height: 30,
                                                            alignment: Alignment.center,
                                                            child: Icon(
                                                              Icons.add,
                                                              size: 16,
                                                              color: _refundQuantity >= _maxQuantity ? Color(0xFFCCCCCC) : Color(0xFF333333),
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
                            const Text(
                              '申请类型',
                              style: TextStyle(
                                fontSize: 14,
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFCCCCCC)),
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
                          const Text(
                            '申请金额',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8), // 添加间距
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _isEditingAmount
                                  ? Expanded(
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF333333),
                                        ),
                                        decoration: const InputDecoration(
                                          prefixText: '¥',
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
                                          fontSize: 24, // 增大字号
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
                                    Icon(_isEditingAmount ? Icons.check : Icons.edit, size: 14, color: Color(0xFF999999)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isEditingAmount ? '完成' : '修改金额',
                                      style: TextStyle(
                                        fontSize: 12,
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
                              const Text(
                                '申请说明',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const Text(
                                '您还可以输入170字',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFEEEEEE)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                hintText: '请您详细填写申请说明',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFCCCCCC),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(12),
                              ),
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // 添加图片按钮
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Color(0xFFEEEEEE)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.camera_alt, size: 24, color: Color(0xFFCCCCCC)),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '上传图片',
                                      style: TextStyle(
                                        fontSize: 12,
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
                height: 44,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    '提交申请',
                    style: TextStyle(
                      fontSize: 16,
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