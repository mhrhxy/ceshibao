import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dingbudaohang.dart'; 
import 'utils/http_util.dart';
import 'config/service_url.dart';
import 'app_localizations.dart';

/// 通知设置页面

// ignore: camel_case_types
class notice extends StatefulWidget {
  const notice({super.key});

  @override
  State<notice> createState() => _Notices();
}

// 通知类型数据模型
class NoticeType {
  final int memberId;
  final String memberName;
  final int managerId;
  final String managerName;
  final String openStatue;
  final String needIm;

  NoticeType({
    required this.memberId,
    required this.memberName,
    required this.managerId,
    required this.managerName,
    required this.openStatue,
    required this.needIm,
  });

  factory NoticeType.fromJson(Map<String, dynamic> json) {
    return NoticeType(
      memberId: json['memberId'],
      memberName: json['memberName'],
      managerId: json['managerId'],
      managerName: json['managerName'],
      openStatue: json['openStatue'],
      needIm: json['needIm'],
    );
  }
}

class _Notices extends State<notice> {
  // 获取通知类型列表
  Future<List<NoticeType>> fetchNoticeTypes() async {
    try {
      var response = await HttpUtil.dio.get(searchNotifyByUserUrl);
      if (response.data['code'] == 200) {
        List<dynamic> data = response.data['data'];
        return data.map((item) => NoticeType.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load notice types');
      }
    } catch (e) {
      print('Error fetching notice types: $e');
      // 不返回模拟数据，返回空列表，以便显示'暂无类型'提示
      return [];
    }
  }
  
  // 存储通知开关状态
  Map<int, bool> _noticeStatus = {};

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
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87, size: 20.w),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)!.translate('notification_settings'),
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
            // 页面内容区域 - 通知开关列表
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(0),
                child: FutureBuilder<List<NoticeType>>(
                  future: fetchNoticeTypes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text(AppLocalizations.of(context)!.translate('load_failed')));
                    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final notice = snapshot.data![index];
                          // 初始化开关状态
                          if (!_noticeStatus.containsKey(notice.managerId)) {
                            _noticeStatus[notice.managerId] = notice.openStatue == '1';
                          }
                          
                          return Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade100, width: 1.0.w),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    notice.managerName,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      color: Colors.black87,
                                    ),
                                  ),
                                Switch(
                                  value: _noticeStatus[notice.managerId] ?? false,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _noticeStatus[notice.managerId] = value;
                                      // 这里可以添加调用更新接口的代码
                                    });
                                  },
                                  activeColor: Colors.green,
                                  activeTrackColor: Colors.green.shade200,
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: Colors.grey.shade300,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    } else {
                      return Center(child: Text(AppLocalizations.of(context)!.translate('no_notification_settings')));
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

