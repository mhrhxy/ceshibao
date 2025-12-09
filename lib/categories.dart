import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dingbudaohang.dart';
import 'search.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';

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
  });

  factory CatelogData.fromJson(Map<String, dynamic> json) {
    return CatelogData(
      catelogId: json['catelogId'] ?? 0,
      parentId: json['parentId'] ?? 0,
      catelogName: json['catelogName'] ?? '',
      catelogNameKr: json['catelogNameKr'] ?? '',
      catelogNameEn: json['catelogNameEn'] ?? '',
      catelogPictureUrl: json['catelogPictureUrl'],
      sort: json['sort'] ?? 0,
      level: json['level'] ?? 0,
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

  final List<Map<String, dynamic>> _productCards = [
    {
      'image': 'https://picsum.photos/300/400?random=20',
      'buttonText': '点击前往',
      'title': '宠物用品大放送',
      'subtitle': '1月限时抢购！！！！',
      'titleColor': Colors.red,
    },
    {
      'image': 'https://picsum.photos/300/400?random=21',
      'buttonText': '点击前往',
      'title': '夏季水果大放送',
      'subtitle': '2月抢购中！！！',
      'titleColor': Colors.cyan,
    },
  ];

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

  Widget _buildCatelogItem(CatelogData catelog) {
    // 获取当前语言
    final String? currentLanguage =
        Provider.of<LanguageProvider>(context, listen: false)
                ?.currentLocale
                ?.languageCode;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultPage(
              category: catelog.getCatelogNameByLanguage(currentLanguage),
            ),
          ),
        );
      },
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Stack(
      children: [
        Image.network(
          product['image'],
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: Colors.white),
        ),
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product['buttonText'],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['title'],
                style: TextStyle(
                  color: product['titleColor'],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                product['subtitle'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
                                    "分类加载失败：$_catelogError",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                )
                              : Column(
                                  children: _catelogRows.map((row) {
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
                                ),
                    ),

                    // 商品卡片区域（保持不变）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: _productCards
                            .map((product) => _buildProductCard(product))
                            .toList(),
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