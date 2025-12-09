import 'package:flutter/material.dart';
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
      debugPrint("规格解析失败：$e");
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
            return const Icon(Icons.star, color: Colors.red, size: 16);
          } else if (rating > (starPosition - 1) && rating % 1 >= 0.5) {
            return const Icon(Icons.star_half, color: Colors.red, size: 16);
          } else {
            return const Icon(Icons.star_border, color: Colors.red, size: 16);
          }
        }),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.red,
            fontSize: 14,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 22,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "我的评论",
                    style: TextStyle(
                      fontSize: 18,
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF4D4F)),
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
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchComments,
              child: const Text("重试"),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          "暂无评论数据",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // 评论列表（将“已购”替换为商品名称）
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => Container(
        height: 1,
        color: Colors.grey[100],
        margin: const EdgeInsets.symmetric(horizontal: 16),
      ),
      itemBuilder: (context, index) {
        final comment = _comments[index];
        return Container(
          padding: const EdgeInsets.all(16),
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
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultShopIcon(),
                              )
                            : _defaultShopIcon(),
                      ),
                      const SizedBox(width: 8),
                      // 店铺名称
                      Text(
                        comment.shopName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. 星星+评分 + 商品名称（原“已购”位置）+ 规格
                  Row(
                    children: [
                      _buildStarWithRating(comment.star),
                      const SizedBox(width: 12),
                      Text(
                        "${comment.productName} ${comment.parsedSpecs}", // 显示商品名称+规格
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3. 评论内容
                  Text(
                    comment.info,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // 4. 商品图片（如有）
                  if (comment.productPicture != null && comment.productPicture!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        comment.productPicture!.startsWith('http') ? comment.productPicture! : 'https:${comment.productPicture!}',
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 100,
                        ),
                      ),
                    ),
                ],
              ),

              // 5. 右下角积分
              Positioned(
                bottom: 0,
                right: 0,
                child: const Text(
                  "1000P",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
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
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.store, size: 18, color: Colors.grey),
    );
  }
}