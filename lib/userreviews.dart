import 'package:flutter/material.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'dart:convert';
import './utils/http_util.dart';

// 评论数据模型（保持不变，移除韩文商品名相关冗余）
class Comment {
  final String shopName; // 店铺名称
  final double star; // 评分
  final String sec; // 原始规格JSON字符串
  final String parsedSpecs; // 解析后的规格名称
  final String info; // 评论内容
  final String? productPicture; // 商品图片
  final String? shopLogo; // 店铺图标
  final String productName; // 中文商品名称（仅保留中文，无需韩文）

  Comment({
    required this.shopName,
    required this.star,
    required this.sec,
    required this.parsedSpecs,
    required this.info,
    this.productPicture,
    this.shopLogo,
    required this.productName,
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
      productName: json['productName']?.toString() ?? '未知商品', // 仅保留中文商品名
    );
  }
}

// 接收memberId参数，用于加载指定用户的评论
class userCommentsPage extends StatefulWidget {
  final String memberId;
  final String nickname;
 const userCommentsPage({super.key, required this.memberId, required this.nickname});

  @override
  State<userCommentsPage> createState() => _userCommentsPageState();
}

class _userCommentsPageState extends State<userCommentsPage> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _errorMsg;
  // 快捷获取传递的 memberId（无语言相关变量，简化代码）
  String get _targetMemberId => widget.memberId;

  @override
  void initState() {
    super.initState();
    // 检查memberId是否有效
    if (_targetMemberId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = "用户ID缺失，无法加载评论";
      });
      return;
    }
    // 加载指定用户的评论
    _fetchTargetUserComments();
  }

  // 加载指定用户的评论（无语言相关逻辑）
  Future<void> _fetchTargetUserComments() async {
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

      // 携带memberId请求指定用户的评论
      final url = "$listByMembers$_targetMemberId";
      final response = await HttpUtil.get(url);

      if (response.data['code'] == 200) {
        List<dynamic> dataList = response.data['data'] ?? [];
        setState(() {
          _comments = dataList.map((item) => Comment.fromJson(item)).toList();
        });
      } else {
        throw Exception(response.data['msg'] ?? '获取用户评论失败');
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
      debugPrint('用户评论接口请求失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 星星 + 评分数字组合组件（保持不变）
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
          // 标题栏：移除语言切换下拉框，仅保留返回键和标题（居中）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                // 返回键
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 22,
                ),
                const SizedBox(width: 12),
                // 标题（居中显示）
                Expanded(
                  child: Text(
                    "${widget.nickname}的评论", // 简化标题，无需显示语言相关
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // 原语言切换位置留空，用SizedBox保持布局平衡
                const SizedBox(width: 40),
              ],
            ),
          ),

          // 可滚动内容区（无语言切换，无积分显示）
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
              onPressed: _fetchTargetUserComments, // 重试加载当前用户评论
              child: const Text("重试"),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          "该用户暂无评论数据",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // 评论列表：移除右下角积分，简化商品名称显示（仅中文）
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
          // 移除Stack中的积分组件，直接用Column展示评论内容
          child: Column(
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

              // 2. 星星+评分 + 商品名称（仅中文）+ 规格
              Row(
                children: [
                  _buildStarWithRating(comment.star),
                  const SizedBox(width: 12),
                  // 直接显示中文商品名，无语言切换
                  Text(
                    "${comment.productName} ${comment.parsedSpecs}",
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
        );
      },
    );
  }

  // 默认店铺图标（保持不变）
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