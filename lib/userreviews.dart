import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'dart:convert';
import './utils/http_util.dart';
import 'package:flutter_mall/app_localizations.dart';

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
      // debugPrint("规格解析失败：$e");
      return "规格信息解析失败"; // 会在UI层转换为国际化文本
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
      // 检查memberId是否有效
      if (_targetMemberId.isEmpty) {
        throw Exception(AppLocalizations.of(context).translate("user_id_missing_comments"));
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context).translate("please_login"));
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
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context).translate("get_user_comments_failed"));
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
      // debugPrint('用户评论接口请求失败: $e');
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
          // 标题栏：移除语言切换下拉框，仅保留返回键和标题（居中）
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1.w)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                // 返回键
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 22.w,
                ),
                SizedBox(width: 12.w),
                // 标题（居中显示）
                Expanded(
                  child: Text(
                    "${widget.nickname}的评论", // 简化标题，无需显示语言相关
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // 原语言切换位置留空，用SizedBox保持布局平衡
                SizedBox(width: 40.w),
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
              onPressed: _fetchTargetUserComments, // 重试加载当前用户评论
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              ),
              child: Text(
                AppLocalizations.of(context).translate("retry"),
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return  Center(
        child: Text(
          AppLocalizations.of(context).translate("user_no_comments"),
          style: TextStyle(color: Colors.grey, fontSize: 16.sp),
        ),
      );
    }

    // 评论列表：移除右下角积分，简化商品名称显示（仅中文）
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
                    comment.shopName == '未知店铺' ? AppLocalizations.of(context).translate('unknown_shop') : comment.shopName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              // 2. 星星+评分 + 商品名称（仅中文）+ 规格
              Row(
                children: [
                  _buildStarWithRating(comment.star),
                  SizedBox(width: 12.w),
                  // 直接显示中文商品名，无语言切换
                  Text(
                    "${comment.productName == '未知商品' ? AppLocalizations.of(context).translate('unknown_product') : comment.productName} ${comment.parsedSpecs == '无规格信息' ? AppLocalizations.of(context).translate('no_spec_info') : comment.parsedSpecs == '规格信息解析失败' ? AppLocalizations.of(context).translate('spec_parse_failed') : comment.parsedSpecs}",
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // 3. 评论内容
              Text(
                comment.info == '无评论内容' ? AppLocalizations.of(context).translate('no_comment_content') : comment.info,
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
        );
      },
    );
  }

  // 默认店铺图标（保持不变）
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