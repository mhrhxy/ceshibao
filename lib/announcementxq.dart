import 'package:flutter/material.dart';
import 'dingbudaohang.dart';
import './config/service_url.dart';
import './utils/http_util.dart';
import 'package:flutter_html/flutter_html.dart';
import 'app_localizations.dart';

/// 公告详情页

class MyAnnouncementDetail extends StatefulWidget {
  final String noticeId;
  
  const MyAnnouncementDetail({super.key, required this.noticeId});

  @override
  State<MyAnnouncementDetail> createState() => _MyAnnouncementDetailState();
}

class _MyAnnouncementDetailState extends State<MyAnnouncementDetail> {
  Map<String, dynamic> announcementDetail = {};
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchAnnouncementDetail();
  }
  
  Future<void> _fetchAnnouncementDetail() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // 替换URL中的{noticeId}占位符
      String url = noticeDetailUrl.replaceAll('{noticeId}', widget.noticeId);
      var response = await HttpUtil.get(url);
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        setState(() {
          // 处理data可能是对象或数组的情况
          if (response.data['data'] is List) {
            // 如果是数组，取第一个元素
            announcementDetail = response.data['data'][0] ?? {};
          } else {
            // 如果是对象，直接使用
            announcementDetail = response.data['data'] ?? {};
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.translate("failed_to_load_announcement_detail") ?? '获取公告详情失败'}: ${response.data?['msg'] ?? '未知错误'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate("failed_to_load_announcement_detail") ?? '获取公告详情失败'}: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    print('接收到的noticeId: ${widget.noticeId}');
    return Scaffold(
      appBar: const FixedActionTopBar(),
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
                        AppLocalizations.of(context)?.translate("announcement_detail") ?? '公告详情',
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
            // 页面内容区域
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : announcementDetail.isNotEmpty
                      ? Container(
                          color: Colors.white,
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 公告标题
                              Text(
                                announcementDetail['noticeTitle'] ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 16),
                              // 公告类型和日期
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    announcementDetail['noticeType'] == '2' ? (AppLocalizations.of(context)?.translate("important") ?? '重要') : (AppLocalizations.of(context)?.translate("normal") ?? '普通'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: announcementDetail['noticeType'] == '2' ? Colors.red : Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    announcementDetail['createTime'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // 公告内容 - 使用Html组件渲染HTML内容
                              Expanded(
                                child: Html(
                                  data: announcementDetail['noticeContent'] ?? '',
                                  style: {
                                    'body': Style(
                                      fontSize: FontSize(16),
                                      color: Colors.black87,
                                      lineHeight: LineHeight(1.6),
                                    ),
                                  },
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(child: Text(AppLocalizations.of(context)?.translate("no_announcements") ?? '暂无公告')),
            ),
          ],
        ),
      ),
    );
  }
}
