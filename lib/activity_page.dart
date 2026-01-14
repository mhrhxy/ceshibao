import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/dingbudaohang.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:url_launcher/url_launcher.dart';

// 活动数据模型
class Activity {
  final ActiveSet activeSet;
  final Coupon coupon;
  final bool? used;

  Activity({
    required this.activeSet,
    required this.coupon,
    this.used,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      activeSet: ActiveSet.fromJson(json['activeSet']),
      coupon: Coupon.fromJson(json['coupon']),
      used: json['used'],
    );
  }
}

// 活动设置模型
class ActiveSet {
  final int activeSetId;
  final String type;
  final int couponId;
  final String activeName;
  final String activeUrl;
  final String? url;
  final String? content;

  ActiveSet({
    required this.activeSetId,
    required this.type,
    required this.couponId,
    required this.activeName,
    required this.activeUrl,
    this.url,
    this.content,
  });

  factory ActiveSet.fromJson(Map<String, dynamic> json) {
    return ActiveSet(
      activeSetId: (json['activeSetId'] ?? 0).toInt(),
      type: json['type'].toString() ?? '',
      couponId: (json['couponId'] ?? 0).toInt(),
      activeName: json['activeName'] ?? '',
      activeUrl: json['activeUrl'] ?? '',
      url: json['url'],
      content: json['content'],
    );
  }
}

// 优惠券模型
class Coupon {
  final int couponId;
  final int activeId;
  final int amount;
  final int returnAmount;
  final String startTime;
  final String endTime;
  final String returnSupport;
  final String type;
  final String newUserUsed;
  final int? couponUseId;
  final int? memberId;
  final String? memberName;
  final String? useTime;
  final String couponUse;

  Coupon({
    required this.couponId,
    required this.activeId,
    required this.amount,
    required this.returnAmount,
    required this.startTime,
    required this.endTime,
    required this.returnSupport,
    required this.type,
    required this.newUserUsed,
    this.couponUseId,
    this.memberId,
    this.memberName,
    this.useTime,
    required this.couponUse,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      couponId: (json['couponId'] ?? 0).toInt(),
      activeId: (json['activeId'] ?? 0).toInt(),
      amount: (json['amount'] ?? 0).toInt(),
      returnAmount: (json['returnAmount'] ?? 0).toInt(),
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      returnSupport: json['returnSupport']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      newUserUsed: json['newUserUsed']?.toString() ?? '',
      couponUseId: json['couponUseId']?.toInt(),
      memberId: json['memberId']?.toInt(),
      memberName: json['memberName'],
      useTime: json['useTime'],
      couponUse: json['couponUse']?.toString() ?? '',
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<Activity> _activityList = [];
  bool _isLoading = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _fetchActivityList();
  }

  // 获取活动列表
  Future<void> _fetchActivityList() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final response = await HttpUtil.get(activityListUrl);
      print('Response data: ${response.data}');
      if (response.data['code'] == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        print('Activity data list: $data');
        setState(() {
          _activityList = data.map((item) => Activity.fromJson(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = response.data['msg'] ?? AppLocalizations.of(context)?.translate('failed_to_get_activity_list') ?? '获取活动列表失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching activities: $e');
      setState(() {
        _errorMsg = AppLocalizations.of(context)?.translate('network_error_retry') ?? '网络请求失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  // 领取优惠券
  Future<void> _claimCoupon(Activity activity) async {
    try {
      // 调用领取优惠券接口
      String url = activityReceiveCouponUrl.replaceAll('{activeId}', activity.activeSet.activeSetId.toString());
      final response = await HttpUtil.post(url);
      
      if (response.data['code'] == 200) {
        // 领取成功，刷新活动列表
        _fetchActivityList();
      } else {
        // 领取失败，显示提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['msg'] ?? AppLocalizations.of(context)?.translate('claim_failed') ?? '领取失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 网络请求失败，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.translate('claim_failed_try_again') ?? '领取失败，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 构建活动卡片
  Widget _buildActivityCard(Activity activity) {
    // 判断是否已领取
    bool isClaimed = activity.used == true || activity.coupon.couponUseId != null;
    
    return GestureDetector(
      onTap: () async {
        // 如果有跳转网址则进行跳转
        if (activity.activeSet.url != null && activity.activeSet.url!.isNotEmpty) {
          // 清理URL，移除可能存在的多余字符
          String url = activity.activeSet.url!.trim();
          if (url.startsWith('`')) url = url.substring(1);
          if (url.endsWith('`')) url = url.substring(0, url.length - 1);
          
          // 使用url_launcher打开网页
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication, // 跳转到外部浏览器打开
            );
          } else {
            // 链接无法打开时的处理
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppLocalizations.of(context)?.translate('cannot_open_link') ?? '无法打开链接'}: $url'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3.w,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 活动图片
            Image.network(
              activity.activeSet.activeUrl.isNotEmpty 
                  ? activity.activeSet.activeUrl 
                  : 'https://picsum.photos/800/400?random=${activity.activeSet.activeSetId}',
              width: double.infinity,
              height: 200.h,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 200.h,
                color: Colors.grey[200],
                child: Center(
                  child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40.w),
                ),
              ),
            ),
            
            // 活动标题和描述
            Positioned(
              left: 16.w,
              top: 16.h,
              right: 16.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.activeSet.activeName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(0, 1.h),
                          blurRadius: 2.w,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${activity.coupon.type == '1' ? AppLocalizations.of(context)?.translate('full_reduction') ?? '满减' : AppLocalizations.of(context)?.translate('discount_coupon') ?? '折扣券'}: 满${activity.coupon.amount}返${activity.coupon.returnAmount}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: Offset(0, 1.h),
                          blurRadius: 2.w,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 右下角按钮
            Positioned(
              right: 16.w,
              bottom: 16.h,
              child: ElevatedButton(
                onPressed: isClaimed ? null : () => _claimCoupon(activity),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white, // 确保禁用状态下文字也是白色
                  side: BorderSide(color: Colors.white, width: 1.w),
                  disabledBackgroundColor: Colors.transparent, // 确保禁用状态下背景也是透明
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 8.h),
                  elevation: 0,
                  textStyle: TextStyle(fontSize: 14.sp),
                ),
                child: Text(
                  isClaimed ? AppLocalizations.of(context)?.translate('already_claimed') ?? '已领取' : AppLocalizations.of(context)?.translate('claim_now') ?? '立即领取',
                  style: TextStyle(
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 返回栏 + 标题
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24.w),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(width: 48.w, height: 48.h),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)?.translate('activity') ?? '活动',
                      style: TextStyle(
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

          // 活动内容区域
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5),
              padding: EdgeInsets.all(16.w),
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.w,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : _errorMsg.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMsg,
                                style: TextStyle(color: Colors.red, fontSize: 14.sp),
                              ),
                              SizedBox(height: 16.h),
                              TextButton(
                                onPressed: _fetchActivityList,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)?.translate('retry') ?? '重试',
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _activityList.length,
                          itemBuilder: (context, index) {
                            return _buildActivityCard(_activityList[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}