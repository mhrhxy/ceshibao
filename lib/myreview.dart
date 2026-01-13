import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'dart:convert';
// 评价页面
class Comment {
  final String shopName; // 店铺名称
  final double star; // 评分
  final String sec; // 原始规格JSON字符串
  final String parsedSpecs; // 解析后的规格名称
  final String info; // 评论内容
  final String? productPicture; // 商品图片
  final String? shopLogo; // 店铺图标
  final String productName; // 中文商品名称
  final String productNameKr; // 韩文商品名称
  final int points; // 积分

  Comment({
    required this.shopName,
    required this.star,
    required this.sec,
    required this.parsedSpecs,
    required this.info,
    this.productPicture,
    this.shopLogo,
    required this.productName,
    required this.productNameKr,
    required this.points,
  });

  // 解析规格JSON字符串，提取所有value_name并拼接
  static String _parseSpecs(String jsonStr) {
    try {
      if (jsonStr.isEmpty) return "无规格信息";
      Map<String, dynamic> specJson = jsonDecode(jsonStr);
      List<dynamic> properties = specJson['properties'] ?? [];
      if (properties.isEmpty) return "无规格信息";
      return properties.map((prop) => prop['value_name'] ?? '').join(' / ');
    } catch (e) {
      return "规格信息解析失败";
    }
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    double starRating = 0;
    try {
      starRating = double.parse(json['star']?.toString() ?? '0');
      starRating = starRating.clamp(0, 5);
    } catch (e) {
      starRating = 0;
    }
    String parsedSpecs = _parseSpecs(json['sec']?.toString() ?? '');
    return Comment(
      shopName: json['shopName']?.toString() ?? '未知店铺',
      star: starRating,
      sec: json['sec']?.toString() ?? '',
      parsedSpecs: parsedSpecs,
      info: json['info']?.toString() ?? '无评论内容',
      productPicture: json['productPicture']?.toString(),
      shopLogo: json['shopLogo']?.toString(),
      productName: json['productName']?.toString() ?? '未知商品', // 解析中文商品名
      productNameKr: json['productNameKr']?.toString() ?? '未知상품', // 解析韩文商品名
      points: int.tryParse(json['points']?.toString() ?? '0') ?? 0, // 解析积分
    );
  }
}

class MyCommentsPage extends StatefulWidget {
  const MyCommentsPage({super.key});

  @override
  State<MyCommentsPage> createState() => _MyCommentsPageState();
}

class _MyCommentsPageState extends State<MyCommentsPage> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _errorMsg;
  String currentLanguage = "中文"; // 默认中文

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('请先登录');
      }

      final dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $token';
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      final response = await dio.get(listByMember);

      if (response.data['code'] == 200) {
        List<dynamic> dataList = response.data['data'] ?? [];
        setState(() {
          _comments = dataList.map((item) => Comment.fromJson(item)).toList();
        });
      } else {
        throw Exception(response.data['msg'] ?? '获取评论失败');
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
      debugPrint('评论接口请求失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 星星 + 评分数字组合组件
  Widget _buildStarWithRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starPosition = index + 1;
          if (rating >= starPosition) {
            return Icon(Icons.star, color: Colors.red, size: 16.w);
          } else if (rating > (starPosition - 1) && rating % 1 >= 0.5) {
            return Icon(Icons.star_half, color: Colors.red, size: 16.w);
          } else {
            return Icon(Icons.star_border, color: Colors.red, size: 16.w);
          }
        }),
        SizedBox(width: 6.w),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: Colors.red,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 标题栏（新增语言切换下拉框）
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1.w)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 22.w,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    "我的评论",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // 可滚动内容区
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D4F)),
          strokeWidth: 2.w,
        ),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMsg!,
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _fetchComments,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
              child: Text(
                "重试",
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return Center(
        child: Text(
          "暂无评论数据",
          style: TextStyle(color: Colors.grey, fontSize: 16.sp),
        ),
      );
    }

    // 评论列表（将“已购”替换为商品名称）
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => Container(
        height: 1.w,
        color: Colors.grey[100],
        margin: EdgeInsets.symmetric(horizontal: 16.w),
      ),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return Container(
          padding: EdgeInsets.all(16.w),
          color: Colors.white,
          child: Stack(
            children: [
              // 评论主体内容
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 店铺图标 + 店铺名称
                  Row(
                    children: [
                      // 店铺图标
                      ClipOval(
                        child: comment.shopLogo != null
                            ? Image.network(
                                comment.shopLogo!.startsWith('http') ? comment.shopLogo! : 'https:${comment.shopLogo!}',
                                width: 32.w,
                                height: 32.h,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultShopIcon(),
                              )
                            : _defaultShopIcon(),
                      ),
                      SizedBox(width: 8.w),
                      // 店铺名称
                      Text(
                        comment.shopName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // 2. 商品名称+规格（上面）+ 星星评分（下面）
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${comment.productName} ${comment.parsedSpecs}", // 显示商品名称+规格
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        softWrap: true, // 允许自动换行
                      ),
                      SizedBox(height: 4.h),
                      _buildStarWithRating(comment.star),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // 3. 评论内容
                  Text(
                    comment.info,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                  ),
                  SizedBox(height: 12.h),

                  // 4. 商品图片（如有）
                  if (comment.productPicture != null && comment.productPicture!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.w),
                      child: Image.network(
                        comment.productPicture!.startsWith('http') ? comment.productPicture! : 'https:${comment.productPicture!}',
                        width: 200.w,
                        height: 150.h,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 100.w,
                        ),
                      ),
                    ),
                ],
              ),

              // 5. 右下角积分
              Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  "${comment.points}P",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 默认店铺图标
  Widget _defaultShopIcon() {
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.store, size: 18.w, color: Colors.grey),
    );
  }
}