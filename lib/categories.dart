import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  String? get fullPictureUrl {
    if (catelogPictureUrl?.isNotEmpty ?? false) {
      String url = catelogPictureUrl!.trim();
      // 如果已经是完整的URL（以http://或https://开头），则直接返回
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
      // 否则拼接baseImageUrl
      return "$baseImageUrl$url";
    }
    return null;
  }
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
        height: 46.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: isSelected ? Border.all(color: Colors.blue, width: 2.w) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1.w,
              blurRadius: 3.w,
              offset: Offset(0, 1.h),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15.r),
              child: catelog.fullPictureUrl != null
                  ? Image.network(
                      catelog.fullPictureUrl!,
                      width: 26.w,
                      height: 26.h,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image(
                          image: AssetImage('images/tht.jpg'),
                          width: 26.w,
                          height: 26.h,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image(
                      image: AssetImage('images/tht.jpg'),
                      width: 26.w,
                      height: 26.h,
                      fit: BoxFit.cover,
                    ),
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                catelog.getCatelogNameByLanguage(currentLanguage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
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
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          child: Stack(
            children: [
              Image.network(
                activeSet['activeUrl']?.isNotEmpty == true
                    ? activeSet['activeUrl']!
                    : 'https://picsum.photos/300/400?random=${activeSet['activeSetId'] ?? activity.hashCode}',
                width: double.infinity,
                height: 200.h,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 200.h,
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.image_not_supported, color: Colors.grey, size: 30.r),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(8.h),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
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
                          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          width: double.infinity,
                          height: 180.h,
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
                          width: 320.w, // 可根据实际logo尺寸调整
                          height: 80.h,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),

                    // 搜索框（保持不变）
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 20.h,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1.w,
                              blurRadius: 3.w,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.h,
                              margin: EdgeInsets.only(left: 12.w),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '淘',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: "",
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                                onSubmitted: (value) {
                                  _jumpToSearchResult(keyword: value);
                                },
                              ),
                            ),
                            Icon(Icons.camera_alt, color: Colors.grey, size: 20.r),
                            SizedBox(width: 8.w),
                            IconButton(
                              icon: Icon(Icons.search, color: Colors.grey, size: 20.r),
                              onPressed: () {
                                _jumpToSearchResult(keyword: _searchController.text);
                              },
                              padding: EdgeInsets.zero,
                            ),
                            SizedBox(width: 4.w),
                          ],
                        ),
                      ),
                    ),

                    // 分类列表（接口数据驱动，支持多语言）
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
                                    // 构建分类行和子分类列表
                                    ...() {
                                      List<Widget> widgets = [];
                                      
                                      // 遍历所有一级分类行
                                      for (int rowIndex = 0; rowIndex < _catelogRows.length; rowIndex++) {
                                        final row = _catelogRows[rowIndex];
                                        
                                        // 添加一级分类行
                                        widgets.add(
                                          Row(
                                            children: List.generate(4, (colIndex) {
                                              if (colIndex >= row.length) {
                                                return const Expanded(child: SizedBox());
                                              }
                                              return Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6.w,
                                                    vertical: 4.h,
                                                  ),
                                                  child: _buildCatelogItem(row[colIndex]),
                                                ),
                                              );
                                            }),
                                          ),
                                        );
                                        
                                        // 检查该行是否包含选中的分类项
                                        bool containsSelected = row.any((catelog) => catelog.catelogId == _selectedCatelogId);
                                        
                                        // 如果包含选中的分类项且有子分类，则在该行后面添加子分类列表
                                        if (containsSelected && _selectedCatelogId != null) {
                                          widgets.add(
                                            Container(
                                              width: double.infinity,
                                              height: 180.h,
                                              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border(
                                                  bottom: BorderSide(color: Colors.grey.shade200, width: 1.w),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    spreadRadius: 1.w,
                                                    blurRadius: 3.w,
                                                    offset: Offset(0, 2.h),
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
                                                                  width: 150.w,
                                                                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text(
                                                                        secondCatelog.getCatelogNameByLanguage(languageCode),
                                                                        style: TextStyle(
                                                                          fontSize: 16.sp,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: Colors.black87,
                                                                        ),
                                                                      ),
                                                                      SizedBox(height: 8.h),
                                                                      Expanded(
                                                                        child: ScrollConfiguration(
                                                                          behavior: ScrollBehavior(),
                                                                          child: SingleChildScrollView(
                                                                            child: Wrap(
                                                                              direction: Axis.vertical,
                                                                              spacing: 6.h,
                                                                              runSpacing: 6.h,
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
                                                                                    style: TextStyle(
                                                                                      fontSize: 14.sp,
                                                                                      color: Colors.black54,
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                              }).toList(),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                            ),
                                          );
                                        }
                                      }
                                      
                                      return widgets;
                                    }().toList(),
                                  ],
                                ),
                    ),

                    // 活动轮播区域（一次展示两个，自动切换）
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      child: _isActivityLoading
                          ? SizedBox(
                              height: 200.h,
                              child: const Center(child: CircularProgressIndicator()),
                            )
                          : _activityError.isNotEmpty
                              ? SizedBox(
                                  height: 200.h,
                                  child: Center(
                                    child: Text(
                                      _activityError,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                )
                              : _activityList.isEmpty
                                  ?  SizedBox(
                                      height: 200.h,
                                      child: Center(
                                        child: Text(
                                          AppLocalizations.of(context)?.translate('no_activity_data') ?? '暂无活动数据',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 200.h,
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