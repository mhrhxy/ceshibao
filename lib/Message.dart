import 'package:flutter/material.dart';
import 'dingbudaohang.dart'; 
import 'utils/http_util.dart';
import 'config/service_url.dart';
import 'package:flutter_html/flutter_html.dart';
import 'announcementxq.dart';
import 'Myorder.dart';
import 'app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// 消息页面

// ignore: camel_case_types
class Message extends StatefulWidget {
  const Message({super.key});

  @override
  State<Message> createState() => _MessageState();
}

class _MessageState extends State<Message> {
  // 当前选中的标签类型 1:订单 2:活动 3:公告
  int _currentTab = 1;
  bool _isLoading = false;
  List<dynamic> _messageList = [];

  // 标签类型映射
  final Map<int, String> _tabLabels = {
    1: '', // 将在build方法中通过本地化设置
    2: '',
    3: '',
  };
  
  get child => null;

  @override
  void initState() {
    super.initState();
    // 页面加载时默认调用第一个标签的接口（订单消息）
    _loadDataByType(1);
  }

  // 根据标签类型调用接口
  Future<void> _loadDataByType(int type) async {
    setState(() {
      _isLoading = true;
      _currentTab = type;
    });

    try {
      if (type == 2) {
        // 活动消息，调用活动列表接口
        final response = await HttpUtil.get(activityListUrl);
        
        // 保存返回的数据
        if (response.data['code'] == 200) {
          final List<dynamic> data = response.data['data'] ?? [];
          setState(() {
            _messageList = data;
          });
        } else {
          // 当接口返回错误时，清空列表
          setState(() {
            _messageList = [];
          });
        }
      } else {
        // 订单消息和公告消息，调用原有的通知接口
        String url = '$searchNotifyByUserTypeUrl$type';
        var response = await HttpUtil.get(url);
        
        // 保存返回的数据
        if (response.data != null && response.data['data'] != null) {
          setState(() {
            _messageList = response.data['data'];
          });
        } else {
          // 当没有data字段时，清空列表
          setState(() {
            _messageList = [];
          });
        }
      }
    } catch (e) {
      // 错误时清空列表
      setState(() {
        _messageList = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 设置本地化标签文本
    _tabLabels[1] = AppLocalizations.of(context)?.translate('order_message') ?? '订单消息';
    _tabLabels[2] = AppLocalizations.of(context)?.translate('activity_message') ?? '活动消息';
    _tabLabels[3] = AppLocalizations.of(context)?.translate('announcement') ?? '公告';
    
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Container(
        color: Color(int.parse('F2F3F5', radix: 16)).withAlpha(255),
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            // 标签切换区域
            Container(
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _tabLabels.entries.map((entry) {
                  int type = entry.key;
                  String label = entry.value;
                  bool isActive = _currentTab == type;
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _loadDataByType(type);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: isActive ? Colors.blue : Colors.black87,
                                fontSize: 16,
                                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                            if (isActive)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                height: 2,
                                width: 40,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // 内容区域 - 根据标签类型显示不同样式的列表
            Expanded(
              child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        color: Color(int.parse('F2F3F5', radix: 16)).withAlpha(255),
                      child: _messageList.isEmpty
                          ? Center(child: Text(_currentTab == 2 ? AppLocalizations.of(context)?.translate('no_activity') ?? '暂无活动' : AppLocalizations.of(context)?.translate('no_message') ?? '暂无消息'))
                          : _currentTab == 3
                              // 公告样式列表
                              ? ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _messageList.length,
                                  itemBuilder: (context, index) {
                                    final item = _messageList[index];
                                    bool isImportant = item['noticeType'] == '2';
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        // 确保传递给详情页的noticeId是字符串类型
                                        String stringNoticeId = item['noticeId'].toString();
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
                                                    item['noticeTitle'] ?? '',
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
                                              data: item['noticeContent'] ?? '',
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
                                                  isImportant ? AppLocalizations.of(context)?.translate('important') ?? '重要' : AppLocalizations.of(context)?.translate('normal') ?? '普通',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isImportant ? const Color.fromRGBO(244, 67, 54, 1) : const Color.fromRGBO(158, 158, 158, 1),
                                                  ),
                                                ),
                                                Text(
                                                  item['createTime'] ?? '',
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
                                )
                              : _currentTab == 2
                                  // 活动消息样式列表
                                  ? ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _messageList.length,
                                      itemBuilder: (context, index) {
                                        final item = _messageList[index];
                                        // 从item中提取activeSet和coupon数据
                                        final activeSet = item['activeSet'] ?? {};
                                        final coupon = item['coupon'] ?? {};
                                        
                                        return GestureDetector(
                                          onTap: () async {
                                            // 如果有跳转网址则进行跳转
                                            if (activeSet['url'] != null && activeSet['url'].isNotEmpty) {
                                              // 清理URL，移除可能存在的多余字符
                                              String url = activeSet['url'].trim();
                                              if (url.startsWith('`')) url = url.substring(1);
                                              if (url.endsWith('`')) url = url.substring(0, url.length - 1);
                                              
                                              // 使用url_launcher打开网页
                                              final uri = Uri.parse(url);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(
                                                  uri,
                                                  mode: LaunchMode.externalApplication, // 跳转到外部浏览器打开
                                                );
                                              }
                                            }
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              children: [
                                                // 活动图片
                                                Image.network(
                                                  activeSet['activeUrl']?.isNotEmpty == true 
                                                      ? activeSet['activeUrl']! 
                                                      : 'https://picsum.photos/800/400?random=${activeSet['activeSetId'] ?? index}',
                                                  width: double.infinity,
                                                  height: 200,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Container(
                                                    width: double.infinity,
                                                    height: 200,
                                                    color: Colors.grey[200],
                                                    child: const Center(
                                                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                                                    ),
                                                  ),
                                                ),
                                                
                                                // 活动标题和描述
                                                Positioned(
                                                  left: 16,
                                                  top: 16,
                                                  right: 16,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        activeSet['activeName'] ?? '',
                                                        style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          shadows: [
                                                            Shadow(
                                                              color: Colors.black.withOpacity(0.5),
                                                              offset: const Offset(0, 1),
                                                              blurRadius: 2,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        '${coupon['type'] == '1' ? AppLocalizations.of(context)?.translate('full_reduction') ?? '满减' : AppLocalizations.of(context)?.translate('discount_coupon') ?? '折扣券'}: 满${coupon['amount']}返${coupon['returnAmount']}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                          shadows: [
                                                            Shadow(
                                                              color: Colors.black.withOpacity(0.5),
                                                              offset: const Offset(0, 1),
                                                              blurRadius: 2,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                
                                                // 右下角按钮
                                                Positioned(
                                                  right: 16,
                                                  bottom: 16,
                                                  child: ElevatedButton(
                                                    onPressed: (item['used'] == true || coupon['couponUseId'] != null) ? null : () async {
                                                      // 调用领取优惠券接口
                                                      String url = activityReceiveCouponUrl.replaceAll('{activeId}', activeSet['activeSetId'].toString());
                                                      try {
                                                        final response = await HttpUtil.post(url);
                                                        
                                                        if (response.data['code'] == 200) {
                                                          // 领取成功，刷新活动列表
                                                          _loadDataByType(2);
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
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent,
                                                      foregroundColor: Colors.white,
                                                      disabledForegroundColor: Colors.white,
                                                      side: BorderSide(color: Colors.white, width: 1),
                                                      disabledBackgroundColor: Colors.transparent,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                                                      elevation: 0,
                                                      textStyle: const TextStyle(fontSize: 14),
                                                    ),
                                                    child: Text(
                                                      (item['used'] == true || coupon['couponUseId'] != null) ? AppLocalizations.of(context)?.translate('already_claimed') ?? '已领取' : AppLocalizations.of(context)?.translate('claim_now') ?? '立即领取',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  // 订单消息样式列表（仅类型1）
                                  : ListView.builder(
                                      itemCount: _messageList.length,
                                      itemBuilder: (context, index) {
                                        final item = _messageList[index];
                                        // 根据已读状态设置卡片颜色
                                        // 安全地将validateRead转换为整数，处理可能的字符串值
                                        int validateRead = 1;
                                        if (item['validateRead'] != null) {
                                          if (item['validateRead'] is String) {
                                            validateRead = int.tryParse(item['validateRead']) ?? 1;
                                          } else if (item['validateRead'] is int) {
                                            validateRead = item['validateRead'] ?? 1;
                                          }
                                        }
                                        Color cardColor = validateRead == 1 
                                            ? Color(int.parse('CAD9EB', radix: 16)).withAlpha(255) // 未读
                                            : Color(int.parse('B2B2B2', radix: 16)).withAlpha(255); // 已读
                                          
                                        return GestureDetector(
                                          onTap: () async {
                                            // 如果已经是已读状态(validateRead != 1)，直接跳转不需要调用接口
                                            if (validateRead != 1) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => Myorder(),
                                                ),
                                              );
                                              return;
                                            }
                                            
                                            // 获取通知ID并安全转换为整数
                                            int notifyId = 0;
                                            if (item['notifyId'] != null) {
                                              if (item['notifyId'] is String) {
                                                notifyId = int.tryParse(item['notifyId']) ?? 0;
                                              } else if (item['notifyId'] is int) {
                                                notifyId = item['notifyId'] ?? 0;
                                              }
                                            }
                                            
                                            if (notifyId > 0) {
                                              try {
                                                // 调用已读接口（仅对未读消息）
                                                var response = await HttpUtil.put(
                                                  readNotifyUrl,
                                                  data: {
                                                    "notifyId": notifyId,
                                                    "validateRead": 2 // 标记为已读
                                                  },
                                                );
                                              } catch (e) {
                                                // 打印错误（可选）
                                                print('已读接口调用失败: $e');
                                              } finally {
                                                // 无论接口调用是否成功，都跳转到我的订单页
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => Myorder(),
                                                  ),
                                                );
                                              }
                                            } else {
                                              // 没有通知ID，直接跳转
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => Myorder(),
                                                ),
                                              );
                                            }
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  // 左侧内容区域
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          '${AppLocalizations.of(context)?.translate('order_no') ?? '订单号: '}${item['notifyNo'] ?? ''}',
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.black87),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          item['message'] ?? '',
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.black),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // 右侧图片区域
                                                  if (item['pictureRow'] != null && item['pictureRow'].isNotEmpty)
                                                    SizedBox(
                                                      width: 80,
                                                      height: 80,
                                                      child: Image.network(
                                                        item['pictureRow'],
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            const Icon(Icons.image_not_supported),
                                                      ),
                                                    )
                                                  else
                                                    // 没有图片时显示默认占位图
                                                    SizedBox(
                                                      width: 80,
                                                      height: 80,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey[200],
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Icon(Icons.shopping_cart_outlined),
                                                      ),
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

