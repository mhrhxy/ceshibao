// 导入计时器相关的库
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart'; // 导入foundation包以使用kDebugMode
import 'dingbudaohang.dart'; // 添加import关键字
import 'app_localizations.dart';
import '../model/coupon_model.dart'; // 导入优惠券模型
import '../utils/http_util.dart'; // 导入网络请求工具
import '../config/service_url.dart'; // 导入接口地址

// 独立的优惠券卡片组件，用于管理倒计时状态
class _CouponCardWidget extends StatefulWidget {
  final CouponData coupon;
  
  const _CouponCardWidget({required this.coupon});
  
  @override
  State<_CouponCardWidget> createState() => _CouponCardWidgetState();
}

class _CouponCardWidgetState extends State<_CouponCardWidget> {
  Timer? _timer; // 将_timer改为可空类型
  Duration _remainingTime = Duration.zero;
  bool _showCountdown = false;
  
  @override
  void initState() {
    super.initState();
    
    // 检查是否有endTime值，如果有则开始倒计时
    if (widget.coupon.endTime.isNotEmpty) {
      _showCountdown = true;
      _calculateRemainingTime();
      
      // 创建计时器，每秒更新一次
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _calculateRemainingTime();
      });
    }
  }
  
  @override
  void dispose() {
    // 清理计时器，只有在_timer不为null时才取消
    _timer?.cancel();
    super.dispose();
  }
  
  // 计算剩余时间
  void _calculateRemainingTime() {
    try {
      // 解析endTime作为倒计时结束时间
      DateTime endTime = DateTime.parse(widget.coupon.endTime);
      DateTime now = DateTime.now();
      
      // 计算当前时间到结束时间的剩余时间
      Duration remaining = endTime.difference(now);
      
      setState(() {
        if (remaining.isNegative) {
          _remainingTime = Duration.zero; // 如果已过期，剩余时间为0
        } else {
          _remainingTime = remaining; // 设置剩余时间
        }
      });
      
      // 如果倒计时结束，停止计时器
      if (_remainingTime == Duration.zero) {
        _timer?.cancel();
      }
    } catch (e) {
      // 解析失败，不显示倒计时
      setState(() {
        _showCountdown = false;
      });
      _timer?.cancel(); // 确保_timer不为null时才取消
    }
  }
  
  // 格式化剩余时间为HH:MM:SS
  String _formatRemainingTime() {
    if (_remainingTime.inSeconds <= 0) {
      return '00时00分00秒';
    }
    
    int days = _remainingTime.inDays;
    int hours = _remainingTime.inHours.remainder(24);
    int minutes = _remainingTime.inMinutes.remainder(60);
    int seconds = _remainingTime.inSeconds.remainder(60);
    
    if (days > 0) {
      // 如果有天数，显示X天HH时MM分SS秒格式
      return '${days}天${hours.toString().padLeft(2, '0')}时${minutes.toString().padLeft(2, '0')}分${seconds.toString().padLeft(2, '0')}秒';
    } else {
      // 如果没有天数，显示HH时MM分SS秒格式
      return '${hours.toString().padLeft(2, '0')}时${minutes.toString().padLeft(2, '0')}分${seconds.toString().padLeft(2, '0')}秒';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // 根据优惠券类型和状态设置颜色
    Color mainColor = Colors.red; // 主色调
    Color backgroundColor = Colors.white; // 背景色
    Color textColor = Colors.black; // 文字颜色
    Color timeColor = Colors.red; // 时间颜色
    String statusText = AppLocalizations.of(context)?.translate('use_now') ?? '立即使用'; // 状态文字
    bool isAvailable = widget.coupon.useType == 0;

    if (widget.coupon.useType == 1) { // 已使用
      mainColor = Colors.grey;
      textColor = Colors.grey;
      timeColor = Colors.grey;
      statusText = AppLocalizations.of(context)?.translate('used') ?? '已使用';
    } else if (widget.coupon.useType == 2) { // 已过期
      mainColor = Colors.grey;
      textColor = Colors.grey;
      timeColor = Colors.grey;
      statusText = AppLocalizations.of(context)?.translate('expired') ?? '已过期';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1.w,
            blurRadius: 3.w,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        children: [
          // 优惠券内容
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                // 金额/折扣部分
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.coupon.type == 1) // 满减券
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₩', // 韩元符号
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${widget.coupon.returnAmount.toInt()}', // 显示满减金额，去除小数
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                  color: mainColor,
                                ),
                              ),
                            ),
                          ],
                        )
                      else // 折扣券
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${widget.coupon.returnAmount.toInt() / 10}折', // 转换为折扣显示，去除小数，例如90 → 9折
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                        ),
                      // 显示使用条件：满多少金额
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${AppLocalizations.of(context)?.translate('min_amount_to_use') ?? '满'}${widget.coupon.amount.toInt()}${AppLocalizations.of(context)?.translate('available') ?? '可用'}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 中间内容部分
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.coupon.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      // 仅在endTime不为空且剩余时间大于0时显示倒计时
                      if (_showCountdown && _remainingTime > Duration.zero)
                        Text(
                          '${AppLocalizations.of(context)?.translate('only') ?? '仅剩'}${_formatRemainingTime()}',
                          style: TextStyle(
                            fontSize: 12.0.sp,
                            fontWeight: FontWeight.bold,
                            color: timeColor,
                          ),
                        ),
                    ],
                  ),
                ),
                // 状态按钮
                Expanded(
                  flex: 2, // 增加flex值以获得更多宽度
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h), // 调整按钮内边距
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp, // 调整文字大小
                            fontWeight: FontWeight.bold,
                          ),
                          softWrap: false, // 禁止文字换行
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  // 标签索引
  int _currentTabIndex = 0;
  // 标签标题
  List<String> get _tabTitles => [
        AppLocalizations.of(context)?.translate('total_coupons') ?? '总优惠券',
        AppLocalizations.of(context)?.translate('available_coupons') ?? '待使用',
        AppLocalizations.of(context)?.translate('used_coupons') ?? '已使用',
        AppLocalizations.of(context)?.translate('expired_coupons') ?? '已过期',
      ];
  // 优惠券数据
  List<CouponData> _coupons = [];
  // 加载状态
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 获取真实优惠券数据
    _fetchCouponData();
  }

  // 获取真实优惠券数据
  Future<void> _fetchCouponData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 根据当前标签确定优惠券类型
      int couponType = 0; // 默认0表示所有
      switch (_currentTabIndex) {
        case 0: // 总优惠券
          couponType = 0;
          break;
        case 1: // 待使用
          couponType = 3;
          break;
        case 2: // 已使用
          couponType = 2;
          break;
        case 3: // 已过期
          couponType = 1;
          break;
      }
      
      // 调用接口获取优惠券数据，替换{type}参数
      String url = myCouponListUrl.replaceAll('{type}', couponType.toString());
      var response = await HttpUtil.dio.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        // 解析接口返回的数据
        var jsonResponse = response.data;
        if (jsonResponse['code'] == 200) {
          // 转换数据格式
          List<CouponData> couponList = [];
          
          // 处理两种不同的返回格式
          if (couponType == 0) {
            // 所有优惠券的情况：data是一个对象，包含1(过期)、2(已使用)、3(未使用)三个数组
            if (jsonResponse['data']['1'] != null) {
              // 处理过期优惠券
              for (var item in jsonResponse['data']['1']) {
                CouponData coupon = CouponData.fromApiJson(item);
                coupon.useType = 2; // 已过期
                couponList.add(coupon);
              }
            }
            if (jsonResponse['data']['2'] != null) {
              // 处理已使用优惠券
              for (var item in jsonResponse['data']['2']) {
                CouponData coupon = CouponData.fromApiJson(item);
                coupon.useType = 1; // 已使用
                couponList.add(coupon);
              }
            }
            if (jsonResponse['data']['3'] != null) {
              // 处理未使用优惠券
              for (var item in jsonResponse['data']['3']) {
                CouponData coupon = CouponData.fromApiJson(item);
                coupon.useType = 0; // 未使用
                couponList.add(coupon);
              }
            }
          } else {
            // 非所有优惠券的情况：data直接是一个数组
            for (var item in jsonResponse['data']) {
              CouponData coupon = CouponData.fromApiJson(item);
              // 根据请求的type设置useType
              switch (couponType) {
                case 1: // 过期
                  coupon.useType = 2;
                  break;
                case 2: // 已使用
                  coupon.useType = 1;
                  break;
                case 3: // 未使用
                  coupon.useType = 0;
                  break;
              }
              couponList.add(coupon);
            }
          }
          
          setState(() {
            _coupons = couponList;
          });
        } else {
          if (kDebugMode) {
            print('获取优惠券失败: ${jsonResponse['msg']}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('获取优惠券异常: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 根据当前标签筛选优惠券
  List<CouponData> _getFilteredCoupons() {
    switch (_currentTabIndex) {
      case 0: // 总优惠券
        return _coupons;
      case 1: // 待使用
        return _coupons.where((coupon) => coupon.useType == 0).toList();
      case 2: // 已使用
        return _coupons.where((coupon) => coupon.useType == 1).toList();
      case 3: // 已过期
        return _coupons.where((coupon) => coupon.useType == 2).toList();
      default:
        return _coupons;
    }
  }

  // 构建优惠券卡片
  Widget _buildCouponCard(CouponData coupon) {
    return _CouponCardWidget(coupon: coupon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          // 自定义导航栏
          Container(
            height: 44.h,
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black, size: 20.w),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8.w),
                Text(
                  AppLocalizations.of(context)?.translate('held_coupons') ?? "我的优惠券",
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
              ],
            ),
          ),

          // 标签栏
          Container(
            height: 48.h,
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: List.generate(_tabTitles.length, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentTabIndex = index;
                      });
                      // 切换标签时重新获取数据
                      _fetchCouponData();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _tabTitles[index],
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: _currentTabIndex == index ? Colors.red : Colors.black,
                            fontWeight: _currentTabIndex == index ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        // 底部指示器
                        if (_currentTabIndex == index)
                          Container(
                            margin: EdgeInsets.only(top: 8.h),
                            width: 20.w,
                            height: 3.h,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // 优惠券列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : () {
                    // 将筛选后的优惠券列表存储在临时变量中，避免多次调用_getFilteredCoupons()
                    final filteredCoupons = _getFilteredCoupons();
                    return filteredCoupons.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.local_offer_outlined,
                                  size: 64.r,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  AppLocalizations.of(context)?.translate('no_coupons') ?? '暂无优惠券',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCoupons.length,
                            itemBuilder: (context, index) {
                              return _buildCouponCard(filteredCoupons[index]);
                            },
                          );
                  }(),
          ),
        ],
      ),
    );
  }
}