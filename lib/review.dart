import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'userreviews.dart';
import 'package:flutter_mall/app_localizations.dart';

// 回复模型（含nickname，用于传递给目标页）
class Reply {
  final String replyId;
  final String observeId;
  final String memberId;
  final String memberType;
  final String targetReplyId;
  final String targetMemberId;
  final String info;
  final String nickname; // 回复者昵称，用于跳转传递
  final String targetMemberNickname;
  final String? pictureUrl;
  final List<Reply> replyChildrens;
  final String? createTime;
  final String? memberAvator; // 回复者头像

  Reply({
    required this.replyId,
    required this.observeId,
    required this.memberId,
    required this.memberType,
    required this.targetReplyId,
    required this.targetMemberId,
    required this.info,
    required this.nickname,
    required this.targetMemberNickname,
    this.pictureUrl,
    this.replyChildrens = const [],
    this.createTime,
    this.memberAvator,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    List<Reply> children = [];
    if (json['replyChildrens'] != null && json['replyChildrens'] is List) {
      children = (json['replyChildrens'] as List)
          .map((childJson) => Reply.fromJson(childJson))
          .toList();
    }
    return Reply(
      replyId: json['replyId'].toString(),
      observeId: json['observeId'].toString(),
      memberId: json['memberId'].toString(),
      memberType: json['memberType'] ?? "",
      targetReplyId: json['targetReplyId'].toString(),
      targetMemberId: json['targetMemberId'].toString(),
      info: json['info'] ?? "",
      nickname: json['nickname'] ?? "匿名用户", // 默认值避免空值
      targetMemberNickname: json['targetMemberNickname'] ?? "",
      pictureUrl: json['pictureUrl'],
      replyChildrens: children,
      createTime: json['createTime'] ?? "",
      memberAvator: json['memberAvator'],
    );
  }
}

// 评论模型（含userName=昵称，用于跳转传递）
class Comment {
  final String id; // observeId
  final String userName; // 评论者昵称，用于跳转传递
  final bool isVip;
  final double star;
  final String sec;
  final String info;
  final String? pictureUrl;
  final List<Reply> replies;
  final String memberId; // 评论者ID，用于跳转传递
  final String? memberAvator; // 评论者头像

  Comment({
    required this.id,
    required this.userName,
    this.isVip = false,
    required this.star,
    required this.sec,
    required this.info,
    this.pictureUrl,
    this.replies = const [],
    required this.memberId,
    this.memberAvator,
  });
}

// 回复弹窗状态管理器（无语言相关逻辑）
class ReplyDialogState {
  bool hasInitiated = false;
  bool isLoading = true;
  List<Reply> replies = [];
  String? errorMsg;
  String? selectedTargetReplyId;
  String? selectedTargetMemberId;
  String? selectedTargetMemberNickname;
}

class ShopReviewsPage extends StatefulWidget {
  final String itemId; // 商品ID（唯一入参）

  const ShopReviewsPage({
    super.key,
    required this.itemId,
  });

  @override
  State<ShopReviewsPage> createState() => _ShopReviewsPageState();
}

class _ShopReviewsPageState extends State<ShopReviewsPage> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadComments(); // 初始化加载商品评论
  }

  // 加载商品评论（无语言相关参数）
  void _loadComments() async {
    try {
      final url = "$listByProductAll${widget.itemId}";
      final response = await Dio().get(url);

      if (response.data['code'] == 200) {
        List<dynamic> rawComments = response.data['data'] ?? [];
        List<Comment> parsedComments = rawComments.map((json) => _convertToComment(json)).toList();
        
        setState(() {
          _comments = parsedComments;
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['msg'] ?? "加载评论失败");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "加载失败：${e.toString()}";
      });
    }
  }

  // 解析评论数据（userName映射为nickname，用于跳转）
  Comment _convertToComment(Map<String, dynamic> json) {
    String secText = "规格信息";
    try {
      if (json['sec'] != null && json['sec'].toString().isNotEmpty) {
        Map<String, dynamic> secJson = jsonDecode(json['sec']);
        List<dynamic> properties = secJson['properties'] ?? [];
        if (properties.isNotEmpty) {
          secText = properties[0]['value_name'] ?? "规格信息";
        }
      }
    } catch (e) {
      secText = "规格信息";
    }

    return Comment(
      id: json['observeId'].toString(),
      userName: json['nickname'] ?? "匿名用户", // 评论者昵称（默认匿名）
      isVip: json['goodObserve'] == "2",
      star: double.tryParse(json['star'] ?? "0") ?? 0,
      sec: secText,
      info: json['info'] ?? "无评论内容",
      pictureUrl: json['pictureUrl'],
      replies: const [],
      memberId: json['memberId'].toString(), // 评论者ID
      memberAvator: json['memberAvator'], // 评论者头像
    );
  }

  // 加载回复列表（无语言相关逻辑）
  Future<List<Reply>> _loadReplyList(String observeId) async {
    try {
      final url = "$replyListByObserveId$observeId";
      final response = await Dio().get(url);

      if (response.data['code'] == 200) {
        List<dynamic> rawReplies = response.data['data'] ?? [];
        return rawReplies.map((json) => Reply.fromJson(json)).toList();
      } else {
        throw Exception(response.data['msg'] ?? "加载回复失败");
      }
    } catch (e) {
      debugPrint("加载回复异常：$e");
      throw Exception("加载回复失败：${e.toString()}");
    }
  }

  // 提交回复（无语言相关参数）
  Future<void> _submitReply({
    required String observeId,
    required String targetReplyId,
    required String targetMemberId,
    required String targetMemberNickname,
    required String content,
    String pictureUrl = "",
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        throw Exception("请先登录");
      }

      final params = {
        "observeId": observeId,
        "targetReplyId": targetReplyId,
        "targetMemberId": targetMemberId,
        "targetMemberNickname": targetMemberNickname,
        "pictureUrl": pictureUrl,
        "info": content,
      };

      final dio = Dio();
      dio.options.headers["Authorization"] = "Bearer $token";
      final response = await dio.post(
        answer,
        data: params,
      );

      if (response.data['code'] != 200) {
        throw Exception(response.data['msg'] ?? "回复失败");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // 核心：点击头像跳转用户评论页（同时传递memberId和nickname）
  void _gotoUserCommentsPage(String memberId, String nickname) {
    if (memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate("user_id_missing"))));
      return;
    }
    // 传递双参数给目标页（userCommentsPage需接收memberId和nickname）
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => userCommentsPage(
          memberId: memberId,
          nickname: nickname, // 新增：传递用户昵称
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const FixedActionTopBar(),
          // 标题栏：仅返回键+评论标题，无语言切换
          Container(
            height: 48.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.w)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24.w),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    "评论",
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w500, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
                // 右侧留空保持布局平衡
                SizedBox(width: 24.w),
              ],
            ),
          ),
          // 评论内容区
          Expanded(child: _buildCommentContent()),
        ],
      ),
    );
  }

  // 构建评论列表（无语言相关逻辑）
  Widget _buildCommentContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMsg != null) {
      return Center(child: Text(_errorMsg!));
    }
    if (_comments.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).translate("no_comment_data")));
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => Divider(
        height: 1.h,
        indent: 16.w,
        endIndent: 16.w,
        color: Color(0xFFF5F5F5),
      ),
      itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
    );
  }

  // 评论项：头像点击传递「评论者ID+昵称」
  Widget _buildCommentItem(Comment comment) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评论者头像+昵称（点击跳转）
          Row(
            children: [
              GestureDetector(
                // 传递评论者的memberId和userName（昵称）
                onTap: () => _gotoUserCommentsPage(comment.memberId, comment.userName),
                behavior: HitTestBehavior.translucent,
                child: ClipOval(
                  child: comment.memberAvator != null
                      ? Image.network(comment.memberAvator!, width: 36.w, height: 36.h, fit: BoxFit.cover)
                      : Icon(Icons.person, size: 36.w, color: Colors.grey),
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                children: [
                  Text(comment.userName, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
                  if (comment.isVip)
                    Padding(
                      padding: EdgeInsets.only(left: 4.w),
                      child: Icon(Icons.verified, color: Colors.red, size: 14.w),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // 评分+规格
          Row(
            children: [
              _buildStarWithRating(comment.star),
              SizedBox(width: 4.w),
              Text("${comment.star}", style: TextStyle(fontSize: 12.sp, color: Colors.red)),
              SizedBox(width: 12.w),
              Text("已购 ${comment.sec}", style: TextStyle(fontSize: 12.sp, color: Color(0xFF999999))),
            ],
          ),
          SizedBox(height: 8.h),
          // 评论内容
          Text(comment.info, style: TextStyle(fontSize: 14.sp, color: Color(0xFF333333), height: 1.5)),
          SizedBox(height: 12.h),
          // 评论图片（如有）
          if (comment.pictureUrl != null && comment.pictureUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4.w),
              child: Image.network(
                comment.pictureUrl!,
                width: 200.w,
                height: 150.h,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200.w,
                    height: 150.h,
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40.w),
                  );
                },
              ),
            ),
          SizedBox(height: 8.h),
          // 回复按钮
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showReplyDialog(context, comment),
              style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8.w), minimumSize: Size(40.w, 24.h)),
              child: Text("评论", style: TextStyle(color: Color(0xFF666666), fontSize: 12.sp)),
            ),
          ),
        ],
      ),
    );
  }

  // 星星评分组件（无语言相关）
  Widget _buildStarWithRating(double rating) {
    return Row(
      children: List.generate(5, (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: Colors.red,
        size: 16.w,
      )),
    );
  }

  // 回复弹窗：回复者头像点击传递「回复者ID+昵称」，提交后刷新列表
  void _showReplyDialog(BuildContext context, Comment comment) {
    final dialogState = ReplyDialogState();
    dialogState.selectedTargetReplyId = "0";
    dialogState.selectedTargetMemberId = comment.memberId;
    dialogState.selectedTargetMemberNickname = comment.userName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // 初始化回复数据
          Future<void> _initReplyData() async {
            if (dialogState.hasInitiated) return;

            try {
              dialogState.hasInitiated = true;
              dialogState.isLoading = true;
              setSheetState(() {});

              List<Reply> replies = await _loadReplyList(comment.id);
              dialogState.replies = replies;
              dialogState.isLoading = false;
              dialogState.errorMsg = null;
              setSheetState(() {});
            } catch (e) {
              dialogState.isLoading = false;
              dialogState.errorMsg = e.toString();
              setSheetState(() {});
            }
          }

          if (!dialogState.hasInitiated) {
            _initReplyData();
          }

          // 选择回复目标
          void _selectReplyTarget(Reply reply) {
            dialogState.selectedTargetReplyId = reply.replyId;
            dialogState.selectedTargetMemberId = reply.memberId;
            dialogState.selectedTargetMemberNickname = reply.nickname;
            setSheetState(() {});
          }

          // 提交回复并刷新列表
          void _onSubmitReply(String content) async {
            if (content.isEmpty) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate("reply_content_empty"))));
              return;
            }

            try {
              await _submitReply(
                observeId: comment.id,
                targetReplyId: dialogState.selectedTargetReplyId ?? "0",
                targetMemberId: dialogState.selectedTargetMemberId ?? comment.memberId,
                targetMemberNickname: dialogState.selectedTargetMemberNickname ?? comment.userName,
                content: content,
              );

              // 提交成功后重新加载回复列表
              List<Reply> newReplies = await _loadReplyList(comment.id);
              dialogState.replies = newReplies;
              setSheetState(() {});
            } catch (e) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }

          final TextEditingController _replyController = TextEditingController();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 弹窗标题栏
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("评论 ${dialogState.replies.length}", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w500)),
                  IconButton(
                    icon: Icon(Icons.close, size: 20.w),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
            Divider(height: 1.h, color: Color(0xFFF5F5F5)),

            // 回复列表：传递「回复者ID+昵称」回调
            SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.6,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: _buildReplyList(
                    replies: dialogState.replies,
                    comment: comment,
                    onSelectTarget: _selectReplyTarget,
                    // 传递带双参数的跳转回调
                    onAvatarTap: (memberId, nickname) => _gotoUserCommentsPage(memberId, nickname),
                  ),
                ),
              ),
            ),
            Divider(height: 1.h, color: Color(0xFFF5F5F5)),

            // 回复输入区
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: dialogState.selectedTargetReplyId == "0"
                            ? "回复 ${comment.userName}"
                            : "回复 @${dialogState.selectedTargetMemberNickname}",
                        hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 14.sp),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.blue, size: 24.w),
                    onPressed: () => _onSubmitReply(_replyController.text.trim()),
                  ),
                ],
              ),
            ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 构建回复列表：onAvatarTap改为双参数（memberId+nickname）
  Widget _buildReplyList({
    required List<Reply> replies,
    required Comment comment,
    required Function(Reply) onSelectTarget,
    required Function(String, String) onAvatarTap, // 双参数回调：ID+昵称
    int indent = 0,
  }) {
    return Column(
      children: [
        for (final reply in replies)
          Column(
            children: [
              Padding(
                padding: EdgeInsets.only(left: (indent >= 20 ? 20 : indent).toDouble()),
                child: _buildReplyItem(
                  reply: reply,
                  comment: comment,
                  onSelectTarget: onSelectTarget,
                  onAvatarTap: onAvatarTap, // 传递双参数回调
                ),
              ),
              // 递归渲染子回复
              if (reply.replyChildrens.isNotEmpty)
                _buildReplyList(
                  replies: reply.replyChildrens,
                  comment: comment,
                  onSelectTarget: onSelectTarget,
                  onAvatarTap: onAvatarTap, // 子回复同样传递双参数
                  indent: 20,
                ),
              SizedBox(height: 8.h),
            ],
          ),
      ],
    );
  }

  // 回复项：头像点击传递「回复者ID+昵称」，图片加载错误显示占位
  Widget _buildReplyItem({
    required Reply reply,
    required Comment comment,
    required Function(Reply) onSelectTarget,
    required Function(String, String) onAvatarTap, // 接收双参数回调
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onSelectTarget(reply),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 回复者头像（点击传递ID+昵称）
            GestureDetector(
              onTap: () => onAvatarTap(reply.memberId, reply.nickname), // 传递回复者ID和昵称
              behavior: HitTestBehavior.translucent,
              child: ClipOval(
                child: reply.memberAvator != null
                    ? Image.network(
                        reply.memberAvator!,
                        width: 30.w,
                        height: 30.h,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 30.w,
                            height: 30.h,
                            color: Colors.grey[200],
                            child: Icon(Icons.person, size: 30.w, color: Colors.grey),
                          );
                        },
                      )
                    : Icon(Icons.person, size: 30.w, color: Colors.grey),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 回复者昵称+回复对象
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: reply.nickname,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                        if (reply.targetReplyId != "0")
                          TextSpan(
                            text: " 回复 @${reply.targetMemberNickname}",
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  // 回复内容
                  Text(
                    reply.info,
                    style: TextStyle(fontSize: 14.sp, color: Color(0xFF333333)),
                  ),
                  SizedBox(height: 4.h),
                  // 回复时间（中文格式化）
                  Text(
                    _formatTime(reply.createTime ?? ""),
                    style: TextStyle(fontSize: 12.sp, color: Color(0xFF999999)),
                  ),
                  // 回复图片（如有，错误时显示占位）
                  if (reply.pictureUrl != null && reply.pictureUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: Image.network(
                          reply.pictureUrl!,
                          width: 100.w,
                          height: 100.h,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100.w,
                              height: 100.h,
                              color: Colors.grey[200],
                              child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40.w),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 时间格式化（中文显示，兼容各种时间差）
  String _formatTime(String timeStr) {
    try {
      if (timeStr.isEmpty) return "";
      DateTime createTime = DateTime.parse(timeStr);
      DateTime now = DateTime.now();
      Duration difference = now.difference(createTime);

      if (difference.inDays > 30) {
        return "${difference.inDays ~/ 30}月前";
      } else if (difference.inDays > 0) {
        return "${difference.inDays}天前";
      } else if (difference.inHours > 0) {
        return "${difference.inHours}小时前";
      } else if (difference.inMinutes > 0) {
        return "${difference.inMinutes}分钟前";
      } else {
        return "刚刚";
      }
    } catch (e) {
      return timeStr;
    }
  }
}