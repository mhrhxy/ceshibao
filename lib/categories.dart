import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dingbudaohang.dart';
import 'search.dart';
import 'activity_page.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'package:flutter_mall/app_localizations.dart';

// 分类数据模型（适配接口返回结构，支持多语言）
class CatelogData {
  final int catelogId;
  final int parentId;
  final String catelogName;
  final String catelogNameKr;
  final String catelogNameEn;
  final String? catelogPictureUrl;
  final int sort;
  final int level;
  final List<CatelogData> children;

  // 统一图片基础地址
  static const String baseImageUrl = baseUrl;

  CatelogData({
    required this.catelogId,
    required this.parentId,
    required this.catelogName,
    required this.catelogNameKr,
    required this.catelogNameEn,
    this.catelogPictureUrl,
    required this.sort,
    required this.level,
    this.children = const [],
  });

  factory CatelogData.fromJson(Map<String, dynamic> json) {
    List<CatelogData> children = [];
    if (json['children'] != null && json['children'] is List) {
      children = (json['children'] as List)
          .map((item) => CatelogData.fromJson(item))
          .toList();
    }
    return CatelogData(
      catelogId: json['catelogId'] ?? 0,
      parentId: json['parentId'] ?? 0,
      catelogName: json['catelogName'] ?? '',
      catelogNameKr: json['catelogNameKr'] ?? '',
      catelogNameEn: json['catelogNameEn'] ?? '',
      catelogPictureUrl: json['catelogPictureUrl'],
      sort: json['sort'] ?? 0,
      level: json['level'] ?? 0,
      children: children,
    );
  }

  // 根据当前语言返回对应名称
  String getCatelogNameByLanguage(String? languageCode) {
    switch (languageCode ?? 'zh') {
      case 'kr':
        return catelogNameKr.isNotEmpty ? catelogNameKr : catelogName;
      case 'en':
        return catelogNameEn.isNotEmpty ? catelogNameEn : catelogName;
      default:
        return catelogName;
    }
  }

  // 拼接完整图片路径
  String get fullPictureUrl =>
      catelogPictureUrl?.isNotEmpty ?? false
          ? "$baseImageUrl${catelogPictureUrl!.trim()}"
          : "https://picsum.photos/50/50?random=default";
}

class Categories extends StatefulWidget {
  const Categories({super.key});

  @override
  State<Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<Categories> {
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  List<CatelogData> _catelogList = [];
  bool _isCatelogLoading = true;
  String _catelogError = "";
  int? _selectedCatelogId;
  List<CatelogData> _subCatelogList = [];
  bool _isSubCatelogLoading = false;
  String _subCatelogError = "";

  List<dynamic> _activityList = [];
  bool _isActivityLoading = true;
  String _activityError = '';
  int _currentIndex = 0; // 当前显示的活动索引
  Timer? _timer; // 自动轮播定时器

  // 分类按行分组（每行4个）
  List<List<CatelogData>> get _catelogRows {
    final rows = <List<CatelogData>>[];
    for (var i = 0; i < _catelogList.length; i += 4) {
      final end = i + 4;
      rows.add(
        _catelogList.sublist(
          i,
          end > _catelogList.length ? _catelogList.length : end,
        ),
      );
    }
    return rows;
  }

  @override
  void initState() {
    super.initState();
    _fetchCatelogData();
    _fetchActivityList();
    
    // 初始化定时器
    _startTimer();
  }

  @override
  void dispose() {
    // 取消定时器
    _timer?.cancel();
    super.dispose();
  }

  // 启动定时器
  void _startTimer() {
    _timer?.cancel();
    // 每3秒自动切换一次
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        // 更新当前索引，实现自动轮播
        _currentIndex = (_currentIndex + 2) % _activityList.length;
      });
    });
  }

  // 重启定时器（在数据加载完成后调用）
  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  // 获取活动列表数据
  Future<void> _fetchActivityList() async {
    setState(() {
      _isActivityLoading = true;
      _activityError = '';
    });

    try {
      final response = await HttpUtil.get(listactivityListUrl);
      if (response.data['code'] == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _activityList = data;
          _isActivityLoading = false;
        });
        
        // 数据加载完成后重启定时器
        _restartTimer();
      } else {
        setState(() {
          _activityError = response.data['msg'] ?? '获取活动列表失败';
          _isActivityLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isActivityLoading = false;
      });
    }
  }

  // 调用分类接口获取数据（适配接口返回结构）
  Future<void> _fetchCatelogData() async {
    setState(() {
      _isCatelogLoading = true;
      _catelogError = "";
    });
    try {
      final response = await _dio.get(catelogListUrl);
      if (response.statusCode == 200) {
        final data = response.data;
        // 解析接口返回的 { "code": 200, "data": [...] } 结构
        if (data is Map && data['code'] == 200 && data['data'] is List) {
          final List<dynamic> dataList = data['data'];
          setState(() {
            _catelogList = dataList.map((item) => CatelogData.fromJson(item)).toList();
            _isCatelogLoading = false;
          });
        } else {
          throw Exception("接口返回数据格式异常");
        }
      } else {
        throw Exception("接口请求失败，状态码：${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _catelogError = e.toString();
        _isCatelogLoading = false;
      });
    }
  }

  // 调用子分类接口获取数据
  Future<void> _fetchSubCatelogData(int parentId) async {
    setState(() {
      _isSubCatelogLoading = true;
      _subCatelogError = "";
    });
    try {
      final response = await _dio.get("$findCatelogByParentId$parentId");
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['code'] == 200 && data['data'] is List) {
          final List<dynamic> dataList = data['data'];
          setState(() {
            _subCatelogList = dataList.map((item) => CatelogData.fromJson(item)).toList();
            _isSubCatelogLoading = false;
          });
        } else {
          throw Exception("子分类接口返回数据格式异常");
        }
      } else {
        throw Exception("子分类接口请求失败，状态码：${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _subCatelogError = e.toString();
        _isSubCatelogLoading = false;
      });
    }
  }

  Widget _buildCatelogItem(CatelogData catelog) {
    // 获取当前语言
    final String? currentLanguage = 
        Provider.of<LanguageProvider>(context, listen: false)
                ?.currentLocale
                ?.languageCode;
    
    final bool isSelected = _selectedCatelogId == catelog.catelogId;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCatelogId = null;
            _subCatelogList = [];
          } else {
            _selectedCatelogId = catelog.catelogId;
            _fetchSubCatelogData(catelog.catelogId);
          }
        });
      },
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              catelog.fullPictureUrl,
              width: 26,
              height: 26,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.image_not_supported, color: Colors.grey, size: 26);
              },
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                catelog.getCatelogNameByLanguage(currentLanguage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.blue : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建活动卡片
  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final activeSet = activity['activeSet'] ?? {};
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // 跳转到活动页面
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ActivityPage(),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            children: [
              Image.network(
                activeSet['activeUrl']?.isNotEmpty == true
                    ? activeSet['activeUrl']!
                    : 'https://picsum.photos/300/400?random=${activeSet['activeSetId'] ?? activity.hashCode}',
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
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    activeSet['activeName'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const FixedActionTopBar(showLogo: false),
      body: Container(
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 顶部图片区域：背景图+logo图叠加
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // 背景图
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('images/bjttb.png'), // 本地背景图路径
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // 居中的logo图
                        Image.asset(
                          'images/logo.png', // 本地logo图路径
                          width: 320, // 可根据实际logo尺寸调整
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),

                    // 搜索框（保持不变）
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '淘',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: "",
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onSubmitted: (value) {
                                  _jumpToSearchResult(keyword: value);
                                },
                              ),
                            ),
                            const Icon(Icons.camera_alt, color: Colors.grey),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.grey),
                              onPressed: () {
                                _jumpToSearchResult(keyword: _searchController.text);
                              },
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),

                    // 分类列表（接口数据驱动，支持多语言）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: _isCatelogLoading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _catelogError.isNotEmpty
                              ? Center(
                                  child: Text(
                                    "${AppLocalizations.of(context)?.translate('catelog_load_failed') ?? '分类加载失败：'}$_catelogError",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                )
                              : Column(
                                  children: [
                                    // 一级分类行
                                    ..._catelogRows.map((row) {
                                      return Row(
                                        children: List.generate(4, (colIndex) {
                                          if (colIndex >= row.length) {
                                            return const Expanded(child: SizedBox());
                                          }
                                          return Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 4,
                                              ),
                                              child: _buildCatelogItem(row[colIndex]),
                                            ),
                                          );
                                        }),
                                      );
                                    }).toList(),
                                    
                                    // 子分类列表
                                    if (_selectedCatelogId != null)
                                      Container(
                                        width: double.infinity,
                                        height: 180,
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(
                                            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              spreadRadius: 1,
                                              blurRadius: 3,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: _isSubCatelogLoading
                                            ? const Center(child: CircularProgressIndicator())
                                            : _subCatelogError.isNotEmpty
                                                ? Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          "${AppLocalizations.of(context)?.translate('sub_catelog_load_failed') ?? '子分类加载失败：'}$_subCatelogError",
                                                          style: const TextStyle(color: Colors.red),
                                                        ),
                                                        TextButton(
                                                          onPressed: _selectedCatelogId != null
                                                              ? () => _fetchSubCatelogData(_selectedCatelogId!)
                                                              : null,
                                                          child: Text(
                                                            AppLocalizations.of(context)?.translate('retry') ?? "重试",
                                                            style: const TextStyle(color: Colors.orange),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : _subCatelogList.isEmpty
                                                    ? Center(
                                                        child: Text(
                                                          AppLocalizations.of(context)?.translate('no_sub_catelog_data') ?? "暂无子分类数据",
                                                          style:  TextStyle(color: Colors.grey),
                                                        ),
                                                      )
                                                    : ListView.builder(
                                                        scrollDirection: Axis.horizontal,
                                                        physics: const ClampingScrollPhysics(),
                                                        itemCount: _subCatelogList.length,
                                                        itemBuilder: (context, secIndex) {
                                                          final secondCatelog = _subCatelogList[secIndex];
                                                          final String? languageCode = 
                                                              Provider.of<LanguageProvider>(context, listen: false)
                                                                      ?.currentLocale
                                                                      ?.languageCode;
                                                          
                                                          return Container(
                                                            width: 150,
                                                            margin: const EdgeInsets.symmetric(horizontal: 8),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  secondCatelog.getCatelogNameByLanguage(languageCode),
                                                                  style: const TextStyle(
                                                                    fontSize: 16,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.black87,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Expanded(
                                                                  child: Wrap(
                                                                    direction: Axis.vertical,
                                                                    spacing: 6,
                                                                    runSpacing: 6,
                                                                    children: secondCatelog.children.map((thirdCatelog) {
                                                                      return GestureDetector(
                                                                        onTap: () {
                                                                          Navigator.push(
                                                                            context,
                                                                            MaterialPageRoute(
                                                                              builder: (context) => SearchResultPage(
                                                                                keyword: thirdCatelog.getCatelogNameByLanguage(languageCode),
                                                                              ),
                                                                            ),
                                                                          );
                                                                        },
                                                                        child: Text(
                                                                          thirdCatelog.getCatelogNameByLanguage(languageCode),
                                                                          style: const TextStyle(
                                                                            fontSize: 14,
                                                                            color: Colors.black54,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                      ),
                                  ],
                                ),
                    ),

                    // 活动轮播区域（一次展示两个，自动切换）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: _isActivityLoading
                          ? const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _activityError.isNotEmpty
                              ? SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Text(
                                      _activityError,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                )
                              : _activityList.isEmpty
                                  ?  SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.of(context)?.translate('no_activity_data') ?? '暂无活动数据',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 200,
                                      child: Row(
                                        children: [
                                          // 第一个活动卡片
                                          _buildActivityCard(_activityList[_currentIndex % _activityList.length]),
                                          // 第二个活动卡片
                                          _buildActivityCard(_activityList[(_currentIndex + 1) % _activityList.length]),
                                        ],
                                      ),
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToSearchResult({String? keyword}) {
    if (keyword?.isNotEmpty ?? false) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultPage(
            keyword: keyword,
          ),
        ),
      );
    }
  }
}