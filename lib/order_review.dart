import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dingbudaohang.dart';
import 'dart:convert';
import 'app_localizations.dart';
import 'config/service_url.dart';
import 'utils/http_util.dart';
import 'Myorder.dart';

class OrderReviewPage extends StatefulWidget {
  final dynamic order; // 可以是OrderData或ShopOrderData类型

  const OrderReviewPage({Key? key, required this.order}) : super(key: key);

  @override
  _OrderReviewPageState createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  List<dynamic> _orderProducts = [];
  bool _isLoading = true;
  Map<int, double> _ratings = {};
  Map<int, TextEditingController> _reviewControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchOrderProducts();
  }

  // 根据订单ID获取商品信息
  Future<void> _fetchOrderProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> params = {'orderIds': widget.order.id};
      var response = await HttpUtil.get(searchOrderProductListUrl, queryParameters: params);
      
      if (response.data != null) {
        Map<String, dynamic> responseData = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (responseData['code'] == 200 && responseData['data'] != null) {
          setState(() {
            _orderProducts = responseData['data'];
            // 初始化评分和评价控制器
            for (int i = 0; i < _orderProducts.length; i++) {
              _ratings[i] = 5.0; // 默认5星
              _reviewControllers[i] = TextEditingController();
            }
          });
        }
      }
    } catch (e) {
      print('获取订单商品信息失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 解析规格信息
  String _parseSpecs(dynamic skuData) {
    String specsText = '';
    if (skuData != null && skuData.toString().isNotEmpty) {
      try {
        var skuJson = json.decode(skuData.toString());
        if (skuJson['properties'] != null && skuJson['properties'] is List) {
          List properties = skuJson['properties'];
          if (properties.isNotEmpty) {
            specsText = properties.map((p) => p['value_name']).where((v) => v != null && v.toString().isNotEmpty).join(' ');
          }
        }
      } catch (e) {
        print('解析规格信息失败: $e');
        // 如果解析失败，回退到使用原始sku数据
        specsText = skuData.toString();
      }
    }
    return specsText.isNotEmpty ? specsText : '无规格';
  }

  // 提交评价
  Future<void> _submitReview() async {
    try {
      bool allSuccess = true;
      
      // 为每个商品提交一条评论
      for (int i = 0; i < _orderProducts.length; i++) {
        var product = _orderProducts[i];
        
        var orderProductInfo = product['orderProductInfo'] ?? {};
        // 构建评论数据
        Map<String, dynamic> reviewData = {
          'orderId': widget.order.id,
          'info': _reviewControllers[i]?.text ?? '',
          'shopId': 0, // 没有店铺ID则传0
          'shopName': (widget.order is ShopOrderData) ? widget.order.shopName : (widget.order.shopName ?? ''), // 店铺名称，根据订单类型获取
          'productId': orderProductInfo['orderProductId'],
          'productName': orderProductInfo['titleCn'] ?? '',
          'productNameKr': orderProductInfo['title'] ?? '',
          'secId': orderProductInfo['skuId'] ?? 0, // 规格ID，当前数据中可能没有
          'sec': orderProductInfo['sku'] ?? '', // 规格字符串JSON格式
          'selfSupport': '1', // 默认不是推荐商品
          'star': _ratings[i].toString(), // 商品评星
          'productPicture': orderProductInfo['imgUrl'] ?? '', // 商品图片
          'pictureUrl': '' // 评价图片，当前未实现图片上传功能
        };

        // 调用提交评论接口
        var response = await HttpUtil.post(insertObserve, data: reviewData);
        
        // 根据接口返回结果处理
        if (response.data != null) {
          Map<String, dynamic> responseData = response.data is String 
              ? json.decode(response.data) 
              : response.data;
          
          if (responseData['code'] != 200) {
            allSuccess = false;
            print('提交商品评价失败: ${product['title']?['zh'] ?? product['title']?['en'] ?? product['title'] ?? ''}');
          }
        } else {
          allSuccess = false;
          print('提交商品评价失败: ${product['title']?['zh'] ?? product['title']?['en'] ?? product['title'] ?? ''}');
        }
      }

      // 显示提交结果
      if (allSuccess) {
        // 评价成功
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.translate('review_submitted') ?? '评价提交成功')),
        );
        // 返回上一页
        Navigator.pop(context);
      } else {
        // 评价失败
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.translate('review_submit_failed') ?? '评价提交失败')),
        );
      }
    } catch (e) {
      print('提交评价失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('review_submit_failed') ?? '评价提交失败')),
      );
    }
  }

  // 评分组件
  Widget _buildRatingStars(int index) {
    return Row(
      children: List.generate(5, (starIndex) {
        return IconButton(
          icon: Icon(
            starIndex < _ratings[index]! ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: () {
            setState(() {
              _ratings[index] = (starIndex + 1).toDouble();
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Container(
        color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            // 标题和返回按钮区域
            Container(
              height: 44.h,
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black, size: 20.w),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.translate('review_product') ?? "评论商品",
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            // 页面内容区域
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16.w),
                child: _isLoading ?
                  const Center(child: CircularProgressIndicator()) :
                  ListView.builder(
                    itemCount: _orderProducts.length,
                    itemBuilder: (context, index) {
                      var product = _orderProducts[index];
                      return Card(
                        color: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 店铺信息
                              Text(
                                widget.order.shopName ?? '',
                                style:  TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              // 商品信息
                              Row(
                                children: [
                                  Image.network(
                                    (product['orderProductInfo']?['imgUrl'] ?? '').replaceAll('`', ''),
                                    width: 80.w,
                                    height: 80.h,
                                    fit: BoxFit.cover,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          // 根据语言环境显示不同标题
                                          AppLocalizations.of(context)?.locale.languageCode == 'zh' ? 
                                          (product['orderProductInfo']?['titleCn'] ?? product['orderProductInfo']?['titleEn'] ?? product['orderProductInfo']?['title'] ?? '') :
                                          AppLocalizations.of(context)?.locale.languageCode == 'en' ?
                                          (product['orderProductInfo']?['titleEn'] ?? product['orderProductInfo']?['titleCn'] ?? product['orderProductInfo']?['title'] ?? '') :
                                          (product['orderProductInfo']?['title'] ?? product['orderProductInfo']?['titleEn'] ?? product['orderProductInfo']?['titleCn'] ?? ''),
                                          style:  TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          '${_parseSpecs(product['orderProductInfo']?['sku'])} x ${product['orderProductInfo']?['quantity'] ?? 1}',
                                          style:  TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              // 评分
                              Text(
                                AppLocalizations.of(context)?.translate('rating') ?? '评分:',
                                style:  TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildRatingStars(index),
                              const SizedBox(height: 16),
                              // 评价输入
                              Text(
                                AppLocalizations.of(context)?.translate('review') ?? '评价:',
                                style:  TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _reviewControllers[index],
                                maxLines: 5,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4.w),
                                  ),
                                  hintText: AppLocalizations.of(context)?.translate('write_your_review') ?? '请输入您的评价',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ),
            ),
            // 提交评价按钮
            Container(
              padding: EdgeInsets.all(16.w),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _submitReview,
                  child: Text(
                    AppLocalizations.of(context).translate('submit_review') ?? '提交评价',
                    style:  TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.w),
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
