// 公告页
import 'package:flutter/material.dart';
import 'dingbudaohang.dart';
import 'package:flutter_mall/config/service_url.dart';
import './utils/http_util.dart'; 
import 'package:flutter_html/flutter_html.dart';
import 'announcementxq.dart';
import 'app_localizations.dart';
// 公告模型类
class NoticeModel {
  // 将noticeId改为dynamic类型，兼容数字和字符串
  dynamic noticeId;
  String noticeTitle;
  String noticeType;
  String noticeContent;
  String status;
  String? createTime; // 创建时间，可能会从接口返回

  NoticeModel({
    required this.noticeId,
    required this.noticeTitle,
    required this.noticeType,
    required this.noticeContent,
    required this.status,
    this.createTime,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    // 添加更健壮的空值处理和类型检查
    try {
      // 处理noticeId，支持数字和字符串类型
      dynamic noticeIdValue = json['noticeId'] ?? '';
      // 确保id在传递时是字符串形式
      if (noticeIdValue is int) {
        noticeIdValue = noticeIdValue.toString();
      }
      
      return NoticeModel(
        noticeId: noticeIdValue,
        noticeTitle: json['noticeTitle'] ?? '',
        noticeType: json['noticeType'] ?? '1',
        noticeContent: json['noticeContent'] ?? '',
        status: json['status'] ?? '0',
        createTime: json['createTime'],
      );
    } catch (e) {
      // 返回默认值，确保程序不会崩溃
      return NoticeModel(
        noticeId: '',
        noticeTitle: '标题加载失败',
        noticeType: '1',
        noticeContent: '',
        status: '0',
        createTime: null,
      );
    }
  }
}

// 公告列表响应模型
class NoticeListResponse {
  int total;
  List<NoticeModel> rows;
  int code;
  String msg;

  NoticeListResponse({
    required this.total,
    required this.rows,
    required this.code,
    required this.msg,
  });

  factory NoticeListResponse.fromJson(Map<String, dynamic> json) {
    var rowsList = json['rows'] as List? ?? [];
    List<NoticeModel> notices = rowsList.map((item) => NoticeModel.fromJson(item)).toList();

    return NoticeListResponse(
      total: json['total'] ?? 0,
      rows: notices,
      code: json['code'] ?? 0,
      msg: json['msg'] ?? '',
    );
  }
}
class NoticePage extends StatefulWidget {
  const NoticePage({super.key});
  @override
  State<NoticePage> createState() => _NoticePages();
}
class _NoticePages extends State<NoticePage> {
  List<NoticeModel> noticeList = [];
  int currentPage = 1;
  int pageSize = 20;
  int totalCount = 0;
  bool isLoading = false;
  bool hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchNoticeList();
    _setupScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        if (!isLoading && hasMoreData) {
          _loadMoreData();
        }
      }
    });
  }

  Future<void> _fetchNoticeList() async {
    setState(() {
      isLoading = true;
    });
    try {
      // 添加请求参数日志
      print('请求公告列表参数: pageNum=$currentPage, pageSize=$pageSize');
      
      var response = await HttpUtil.get(noticeListUrl, queryParameters: {
        'pageNum': currentPage,
        'pageSize': pageSize,
      });
      if (response.statusCode == 200) {
        try {
          // 单独捕获数据解析异常
          NoticeListResponse noticeResponse = NoticeListResponse.fromJson(response.data);
          
          if (noticeResponse.code == 200) {
            setState(() {
              if (currentPage == 1) {
                noticeList = noticeResponse.rows;
              } else {
                noticeList.addAll(noticeResponse.rows);
              }
              totalCount = noticeResponse.total;
              hasMoreData = noticeList.length < totalCount;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${noticeResponse.msg}')),
            );
          }
        } catch (parseError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据解析失败')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络请求失败，状态码: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.translate("failed_to_load_announcements") ?? '获取公告列表失败')),
          );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _loadMoreData() {
    if (hasMoreData && !isLoading) {
      setState(() {
        currentPage++;
      });
      _fetchNoticeList();
    }
  }

  void _refreshData() {
    setState(() {
      currentPage = 1;
      noticeList.clear();
      hasMoreData = true;
    });
    _fetchNoticeList();
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
                        AppLocalizations.of(context)?.translate("announcement") ?? '公告',
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
              child: isLoading && currentPage == 1
                  ? const Center(child: CircularProgressIndicator())
                  : noticeList.isEmpty
                      ? Center(child: Text(AppLocalizations.of(context)?.translate("no_announcements") ?? "暂无公告"))
                      : RefreshIndicator(
                          onRefresh: () async {
                            _refreshData();
                          },
                          color: Colors.black87,
                          child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: noticeList.length + (hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == noticeList.length) {
                              // 加载更多指示器
                              return isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  : Container();
                            }
                            
                            final notice = noticeList[index];
                            bool isImportant = notice.noticeType == '2';
                            
                            return GestureDetector(
                              onTap: () {
                                // 确保传递给详情页的noticeId是字符串类型
                                String stringNoticeId = notice.noticeId.toString();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MyAnnouncementDetail(noticeId: stringNoticeId),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide.none,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                    Row(
                                      children: [
                                        // 公告类型标识
                                        // 根据公告重要性显示不同的图片
                                        Image(
                                          image: AssetImage(isImportant ? 'images/zhong.png' : 'images/pu.png'),
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 8),
                                        // 公告标题
                                        Expanded(
                                          child: Text(
                                            notice.noticeTitle,
                                            style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isImportant ? Colors.red : const Color.fromARGB(221, 145, 144, 144),
                                          ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1, color: Color.fromARGB(221, 231, 229, 229)),
                                    const SizedBox(height: 8),
                                    // 公告内容预览 - 使用Html组件渲染HTML内容
                                    Html(
                                      data: notice.noticeContent,
                                      style: {
                                        'body': Style(
                                          fontSize: FontSize(14),
                                          color: Colors.grey[600],
                                          margin: Margins.zero,
                                          padding: HtmlPaddings.zero,
                                          maxLines: 2,
                                          textOverflow: TextOverflow.ellipsis,
                                        ),
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    // 公告类型和时间
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isImportant ? (AppLocalizations.of(context)?.translate("important") ?? '重要') : (AppLocalizations.of(context)?.translate("normal") ?? '普通'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isImportant ? const Color.fromRGBO(244, 67, 54, 1) : const Color.fromRGBO(158, 158, 158, 1),
                                          ),
                                        ),
                                        Text(
                                          notice.createTime ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  ),
                                ),
                              ),
                            );
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
