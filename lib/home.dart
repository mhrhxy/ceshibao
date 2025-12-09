import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:provider/provider.dart';
import 'dingbudaohang.dart';
import 'language_provider.dart';
import 'top_area_widget.dart';

// 统一图片基础地址
const String baseImageUrl = "http://192.168.0.120:8080";

// 自定义无滚动条行为
class NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

// 轮播图模型
class CarouselModel {
  final String msg;
  final int code;
  final List<CarouselData> data;

  CarouselModel({required this.msg, required this.code, required this.data});

  factory CarouselModel.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] is List ? json['data'] as List : [];
    List<CarouselData> carouselList =
        dataList.map((item) => CarouselData.fromJson(item)).toList();
    return CarouselModel(
      msg: json['msg'] ?? '',
      code: json['code'] ?? -1,
      data: carouselList,
    );
  }
}

class CarouselData {
  final int carouselId;
  final String pictureUrl;
  final String redirectUrl;
  final int sort;

  String get fullPictureUrl => "$baseImageUrl${pictureUrl.trim()}";

  CarouselData({
    required this.carouselId,
    required this.pictureUrl,
    required this.redirectUrl,
    required this.sort,
  });

  factory CarouselData.fromJson(Map<String, dynamic> json) {
    return CarouselData(
      carouselId: json['carouselId'] ?? 0,
      pictureUrl: json['pictureUrl'] ?? '',
      redirectUrl: json['redirectUrl'] ?? '',
      sort: json['sort'] ?? 0,
    );
  }
}

// 分类模型
class CatelogModel {
  final String msg;
  final int code;
  final List<CatelogData> data;

  CatelogModel({required this.msg, required this.code, required this.data});

  factory CatelogModel.fromJson(Map<String, dynamic> json) {
    var dataList = json['data'] is List ? json['data'] as List : [];
    List<CatelogData> catelogList =
        dataList.map((item) => CatelogData.fromJson(item)).toList();
    return CatelogModel(
      msg: json['msg'] ?? '',
      code: json['code'] ?? -1,
      data: catelogList,
    );
  }
}

class CatelogData {
  final int catelogId;
  final String catelogName;
  final String catelogNameKr;
  final String catelogNameEn;
  final String? catelogPictureUrl;
  final int sort;
  final List<CatelogData> children;

  String? get fullPictureUrl =>
      catelogPictureUrl?.isNotEmpty ?? false
          ? "$baseImageUrl${catelogPictureUrl!.trim()}"
          : null;

  CatelogData({
    required this.catelogId,
    required this.catelogName,
    required this.catelogNameKr,
    required this.catelogNameEn,
    this.catelogPictureUrl,
    required this.sort,
    required this.children,
  });

  factory CatelogData.fromJson(Map<String, dynamic> json) {
    var childrenList = json['children'] is List ? json['children'] as List : [];
    List<CatelogData> children =
        childrenList.map((item) => CatelogData.fromJson(item)).toList();
    return CatelogData(
      catelogId: json['catelogId'] ?? 0,
      catelogName: json['catelogName']?.toString() ?? '',
      catelogNameKr: json['catelogNameKr']?.toString() ?? '',
      catelogNameEn: json['catelogNameEn']?.toString() ?? '',
      catelogPictureUrl: json['catelogPictureUrl'],
      sort: json['sort'] ?? 0,
      children: children,
    );
  }

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
}

// 评论模型
class ObserveData {
  final String productName;
  final String productNameKr;
  final String shopName;
  final String sec;
  final String info;
  final int star;
  final String productPicture;

  String get fullProductPicture =>
      productPicture.isNotEmpty
          ? "$baseImageUrl${productPicture.trim()}"
          : "https://picsum.photos/200/200?random=default";

  ObserveData({
    required this.productName,
    required this.productNameKr,
    required this.shopName,
    required this.sec,
    required this.info,
    required this.star,
    required this.productPicture,
  });

  factory ObserveData.fromJson(Map<String, dynamic> json) {
    return ObserveData(
      productName: json['productName']?.toString() ?? "未知商品",
      productNameKr: json['productNameKr']?.toString() ?? "",
      shopName: json['shopName']?.toString() ?? "未知店铺",
      sec: json['sec']?.toString() ?? "默认规格",
      info: json['info']?.toString() ?? "暂无评论内容",
      star: int.tryParse(json['star']?.toString() ?? "0") ?? 0,
      productPicture: json['productPicture']?.toString() ?? "",
    );
  }
}

// Home主组件
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late EasyRefreshController _refreshController;
  late PageController _commentPageController;
  late Timer _commentTimer;
  int _currentCommentIndex = 0;
  List<int>? _selectedCatelogIndex;

  // 原有状态数据
  List<CarouselData> _carouselList = [];
  bool _isCarouselLoading = true;
  String _carouselErrorMsg = "";
  List<CatelogData> _catelogList = [];
  bool _isCatelogLoading = true;
  String _catelogErrorMsg = "";
  List<CatelogData> _subCatelogList = [];
  bool _isSubCatelogLoading = false;
  String _subCatelogErrorMsg = "";
  int? _selectedParentId;

  List<ObserveData> _observeList = [];
  bool _isCommentLoading = true;
  String _commentErrorMsg = "";

  // 文字搜索状态
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchLoading = false;

  // 图片搜索相关状态
  final ImagePicker _imagePicker = ImagePicker();
  bool _isImageSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshController = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    _commentPageController = PageController(viewportFraction: 1.0);
    _startCommentTimer();
    _fetchAllData();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _commentPageController.dispose();
    _commentTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // 批量加载原有数据
  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchCarouselData(),
      _fetchCatelogData(),
      _fetchCommentData(),
    ]);
  }

  // 评论接口请求
  Future<void> _fetchCommentData() async {
    setState(() {
      _isCommentLoading = true;
      _commentErrorMsg = "";
    });

    try {
      Response response = await HttpUtil.get(observelist);
      List<dynamic> dataList = [];
      if (response.data is List) {
        dataList = response.data as List;
      } else if (response.data is Map && response.data['data'] is List) {
        dataList = response.data['data'] as List;
      }

      setState(() {
        _observeList =
            dataList.map((item) => ObserveData.fromJson(item)).toList();
        _isCommentLoading = false;
      });
    } catch (e) {
      setState(() {
        _commentErrorMsg = "评论数据加载异常";
        _isCommentLoading = false;
      });
    }
  }

  // 轮播图接口
  Future<void> _fetchCarouselData() async {
    setState(() {
      _isCarouselLoading = true;
      _carouselErrorMsg = "";
    });

    try {
      Response response = await HttpUtil.get(carouselListUrl);
      CarouselModel model = CarouselModel.fromJson(response.data);
      if (model.code == 200) {
        setState(
          () =>
              _carouselList =
                  model.data..sort((a, b) => a.sort.compareTo(b.sort)),
        );
      } else {
        setState(
          () =>
              _carouselErrorMsg =
                  model.msg.isNotEmpty
                      ? model.msg
                      : AppLocalizations.of(
                            context,
                          )?.translate('carousel_load_failed') ??
                          "轮播图加载失败",
        );
      }
    } catch (e) {
      setState(
        () =>
            _carouselErrorMsg =
                e is DioError
                    ? AppLocalizations.of(
                          context,
                        )?.translate('network_error') ??
                        "网络异常，请重试"
                    : "轮播图加载异常",
      );
    } finally {
      if (mounted) setState(() => _isCarouselLoading = false);
    }
  }

  // 分类接口
  Future<void> _fetchCatelogData() async {
    setState(() {
      _isCatelogLoading = true;
      _catelogErrorMsg = "";
    });

    try {
      Response response = await HttpUtil.get(catelogListUrl);
      CatelogModel model = CatelogModel.fromJson(response.data);
      if (model.code == 200) {
        setState(
          () =>
              _catelogList =
                  model.data..sort((a, b) => a.sort.compareTo(b.sort)),
        );
      } else {
        setState(
          () =>
              _catelogErrorMsg =
                  model.msg.isNotEmpty
                      ? model.msg
                      : AppLocalizations.of(
                            context,
                          )?.translate('catelog_load_failed') ??
                          "分类加载失败",
        );
      }
    } catch (e) {
      setState(
        () =>
            _catelogErrorMsg =
                e is DioError
                    ? AppLocalizations.of(
                          context,
                        )?.translate('network_error') ??
                        "网络异常，请重试"
                    : "分类加载异常",
      );
    } finally {
      if (mounted) setState(() => _isCatelogLoading = false);
    }
  }

  // 子分类接口
  Future<void> _fetchSubCatelogData(int parentId) async {
    setState(() {
      _isSubCatelogLoading = true;
      _subCatelogErrorMsg = "";
      _selectedParentId = parentId;
    });

    try {
      String url = "$findCatelogByParentId$parentId";
      Response response = await HttpUtil.get(url);
      CatelogModel model = CatelogModel.fromJson(response.data);
      if (model.code == 200) {
        setState(
          () =>
              _subCatelogList =
                  model.data..sort((a, b) => a.sort.compareTo(b.sort)),
        );
      } else {
        setState(
          () =>
              _subCatelogErrorMsg =
                  model.msg.isNotEmpty
                      ? model.msg
                      : AppLocalizations.of(
                            context,
                          )?.translate('sub_catelog_load_failed') ??
                          "子分类加载失败",
        );
      }
    } catch (e) {
      setState(
        () =>
            _subCatelogErrorMsg =
                e is DioException
                    ? AppLocalizations.of(
                          context,
                        )?.translate('network_error') ??
                        "网络异常，请重试"
                    : "子分类加载异常",
      );
    } finally {
      if (mounted) setState(() => _isSubCatelogLoading = false);
    }
  }

  // 文字搜索接口调用
  Future<void> _fetchSearchData(String keyword) async {
    // 获取当前语言
    final String currentLanguage =
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).currentLocale?.languageCode ??
        "ko";

    // 准备请求参数
    final Map<String, dynamic> searchParams = {
      "keyword": keyword.trim(),
      "sort": "",
      "pageNo": "1",
      "pageSize": "10",
      "filters": [],
      "language": currentLanguage,
    };

    // 显示加载状态
    setState(() => _isSearchLoading = true);

    try {
      await HttpUtil.post(searchByKeyword, data: searchParams);

      // 接口调用成功
      print("搜索接口调用成功，关键词：$keyword");
    } catch (e) {
      // 处理错误
      print("搜索接口调用失败：$e");
    } finally {
      // 隐藏加载状态
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  // 打开图片来源选择（相册/相机）- 保留国际化
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    AppLocalizations.of(context)?.translate('select_image_source') ?? "选择图片来源",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                // 相册选择
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(AppLocalizations.of(context)?.translate('album') ?? "相册"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                // 相机拍摄
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(AppLocalizations.of(context)?.translate('camera') ?? "相机"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                // 取消按钮
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)?.translate('cancel') ?? "取消",
                    textAlign: TextAlign.center,
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
    );
  }

  // 选择图片（仅移动端逻辑）
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        return;
      }

      await _uploadImageToTaobao(pickedFile);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.translate('image_selection_failed') ?? "图片选择失败，请重试")
        )
      );
    }
  }

  // 图片上传（仅移动端逻辑，删除Web端代码）
  Future<void> _uploadImageToTaobao(XFile imageFile) async {
    setState(() => _isImageSearchLoading = true);
    try {
      // 移动端直接读取字节数据
      final List<int> imageBytes = await imageFile.readAsBytes();
      print("移动端图片读取成功，字节长度：${imageBytes.length}");

      // Base64转换与接口调用
      final String base64Image = base64Encode(imageBytes);
      final Response response = await HttpUtil.dio.post(
        taobaoimg,
        data: {"imageBase64": base64Image},
        options: Options(
          contentType: "application/json",
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data["code"] == 200) {
        final String imageId = response.data["msg"];
        await _searchByImage(imageId);
      } else {
        throw Exception(
          "${AppLocalizations.of(context)?.translate('image_upload_failed') ?? "图片上传失败"}：${response.data["msg"] ?? "未知错误"}"
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${AppLocalizations.of(context)?.translate('image_upload_failed') ?? "图片上传失败"}：${e.toString().substring(0, 80)}...",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImageSearchLoading = false);
    }
  }

  // 图片搜索接口
  Future<void> _searchByImage(String imageId) async {
    setState(() => _isImageSearchLoading = true);

    try {
      final String currentLanguage =
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).currentLocale?.languageCode ??
          "ko";

      final Map<String, dynamic> searchParams = {
        "imageId": imageId,
        "language": currentLanguage,
      };

      final Response response = await HttpUtil.dio.post(
        searchByImage,
        data: searchParams,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.translate('image_search_request_sent') ?? "图片搜索请求已发送")
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${AppLocalizations.of(context)?.translate('image_search_failed') ?? "图片搜索失败"}：${e.toString().substring(0, 50)}..."
          )
        )
      );
    } finally {
      if (mounted) setState(() => _isImageSearchLoading = false);
    }
  }

  // 评论轮播
  void _startCommentTimer() {
    _commentTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _observeList.isNotEmpty) {
        setState(() {
          final pageCount = (_observeList.length + 1) ~/ 2;
          _currentCommentIndex = (_currentCommentIndex + 1) % pageCount;
          _commentPageController.animateToPage(
            _currentCommentIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  // 评论项组件
  Widget _buildCommentItem(ObserveData comment) {
    final String? languageCode =
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).currentLocale?.languageCode;
    final int starCount = comment.star.clamp(0, 5);
    final String showProductName =
        (languageCode == 'kr' && comment.productNameKr.isNotEmpty)
            ? comment.productNameKr
            : comment.productName;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  Icons.star,
                  color:
                      index < starCount ? Colors.orange : Colors.grey.shade300,
                  size: 16,
                );
              }),
            ),
            const SizedBox(height: 2),
            Text(
              showProductName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 65,
                  height: 95,
                  margin: const EdgeInsets.only(right: 6),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Image.network(
                    comment.fullProductPicture,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                        size: 65,
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        comment.sec,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.info,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                      const SizedBox(height: 50),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.block,
                            color: Colors.grey,
                            size: 14,
                          ),
                          label: const Text(
                            '屏蔽',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 一级分类按行分组
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

  // 横向滚动拦截
  Widget _horizontalScrollInterceptor({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollStartNotification ||
            notification is ScrollEndNotification) {
          return true;
        }
        return false;
      },
      child: GestureDetector(
        onHorizontalDragDown: (details) {},
        onHorizontalDragStart: (details) {},
        onHorizontalDragUpdate: (details) {},
        onHorizontalDragEnd: (details) {},
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }

  // 分类弹框
  Widget _buildCatelogPopup() {
    final String? languageCode =
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).currentLocale?.languageCode;

    return Container(
      width: double.infinity,
      height: 200,
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
      child: _horizontalScrollInterceptor(
        child: ScrollConfiguration(
          behavior: NoScrollbarBehavior(),
          child:
              _isSubCatelogLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.orange,
                      strokeWidth: 2,
                    ),
                  )
                  : _subCatelogErrorMsg.isNotEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _subCatelogErrorMsg,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        TextButton(
                          onPressed:
                              () =>
                                  _selectedParentId != null
                                      ? _fetchSubCatelogData(_selectedParentId!)
                                      : null,
                          child: Text(
                            AppLocalizations.of(context)?.translate('retry') ??
                                "重试",
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  )
                  : _subCatelogList.isEmpty
                  ? const Center(
                    child: Text(
                      "暂无子分类数据",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _subCatelogList.length,
                    itemBuilder: (context, secIndex) {
                      final secondCatelog = _subCatelogList[secIndex];
                      final List<CatelogData> thirdCatelogList =
                          secondCatelog.children;

                      return Container(
                        width: 150,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              secondCatelog.getCatelogNameByLanguage(
                                languageCode,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: NoScrollbarBehavior(),
                                child: SingleChildScrollView(
                                  child: Wrap(
                                    direction: Axis.vertical,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children:
                                        thirdCatelogList.map((thirdCatelog) {
                                          return Text(
                                            thirdCatelog
                                                .getCatelogNameByLanguage(
                                                  languageCode,
                                                ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
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
      ),
    );
  }

  // 一级分类项
  Widget _buildCatelogItem(int rowIndex, int colIndex) {
    final catelogRows = _catelogRows;
    if (rowIndex >= catelogRows.length ||
        colIndex >= catelogRows[rowIndex].length) {
      return const SizedBox();
    }
    final CatelogData catelog = catelogRows[rowIndex][colIndex];
    final isSelected =
        _selectedCatelogIndex != null &&
        _selectedCatelogIndex![0] == rowIndex &&
        _selectedCatelogIndex![1] == colIndex;
    final String? languageCode =
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).currentLocale?.languageCode;

    return GestureDetector(
      onTap: () {
        setState(
          () =>
              _selectedCatelogIndex = isSelected ? null : [rowIndex, colIndex],
        );
        if (!isSelected) {
          _fetchSubCatelogData(catelog.catelogId);
        } else {
          setState(() => _subCatelogList = []);
        }
      },
      behavior: HitTestBehavior.opaque,
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
          children: [
            if (catelog.fullPictureUrl != null)
              Image.network(
                catelog.fullPictureUrl!,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.category,
                      color: Colors.grey,
                      size: 26,
                    ),
              )
            else
              const Icon(Icons.category, color: Colors.grey, size: 26),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                catelog.getCatelogNameByLanguage(languageCode),
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_selectedCatelogIndex != null) {
          setState(() {
            _selectedCatelogIndex = null;
            _subCatelogList = [];
          });
        }
      },
      child: Scaffold(
        appBar: const FixedActionTopBar(),
        body: TopAreawidget(
          color: Colors.white,
          child: Container(
            color: Colors.white,
              child: CustomScrollView(
              shrinkWrap: false,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 搜索框（包含文字搜索和图片搜索）
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(20),
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
                          // 文字搜索输入框
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    AppLocalizations.of(
                                      context,
                                    )?.translate('input_search_hint') ??
                                    "请输入搜索关键词",
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              // 回车键触发搜索
                              onSubmitted: (value) => _fetchSearchData(value),
                            ),
                          ),
                          // 相机图标（图片搜索入口）
                          IconButton(
                            icon:
                                _isImageSearchLoading
                                    ? const CircularProgressIndicator(
                                      color: Colors.grey,
                                      strokeWidth: 2,
                                    )
                                    : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.grey,
                                    ),
                            onPressed:
                                _isImageSearchLoading
                                    ? null
                                    : _showImageSourceActionSheet,
                          ),
                          // 搜索按钮（文字搜索）
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.grey),
                            onPressed: () {
                              final keyword = _searchController.text;
                              if (keyword.trim().isNotEmpty) {
                                _fetchSearchData(keyword);
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),

                // 轮播图
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: _horizontalScrollInterceptor(
                      child: Container(
                        height: 200,
                        child:
                            _isCarouselLoading
                                ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.orange,
                                    strokeWidth: 2,
                                  ),
                                )
                                : _carouselErrorMsg.isNotEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _carouselErrorMsg,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _fetchCarouselData,
                                        child: Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.translate('retry') ??
                                              "重试",
                                          style: const TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : _carouselList.isEmpty
                                ? const SizedBox()
                                : Swiper(
                                  itemCount: _carouselList.length,
                                  autoplay: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final carousel = _carouselList[index];
                                    return Image.network(
                                      carousel.fullPictureUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey[100],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                    );
                                  },
                                ),
                      ),
                    ),
                  ),
                ),

                // 商品分类
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, rowIndex) {
                        if (_isCatelogLoading) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        }
                        if (_catelogErrorMsg.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _catelogErrorMsg,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _fetchCatelogData,
                                    child: Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('retry') ??
                                          "重试",
                                      style: const TextStyle(
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        if (_catelogList.isEmpty) {
                          return const SizedBox();
                        }
                        final rowCatelogs = _catelogRows[rowIndex];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: List.generate(4, (colIndex) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: _buildCatelogItem(
                                      rowIndex,
                                      colIndex,
                                    ),
                                  ),
                                );
                              }),
                            ),
                            if (_selectedCatelogIndex != null &&
                                _selectedCatelogIndex![0] == rowIndex)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: _buildCatelogPopup(),
                              ),
                          ],
                        );
                      },
                      childCount:
                          _isCatelogLoading ||
                                  _catelogErrorMsg.isNotEmpty ||
                                  _catelogList.isEmpty
                              ? 1
                              : _catelogRows.length,
                    ),
                  ),
                ),

                // 评论区
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    height: 200,
                    child:
                        _isCommentLoading
                            ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: CircularProgressIndicator(
                                  color: Colors.orange,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                            : _commentErrorMsg.isNotEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 30,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      _commentErrorMsg,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _fetchCommentData(),
                                      child: const Text(
                                        "重试",
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : _observeList.isEmpty
                            ? const SizedBox()
                            : SizedBox(
                              height: 220,
                              child: PageView.builder(
                                controller: _commentPageController,
                                physics: const ClampingScrollPhysics(),
                                itemCount: (_observeList.length + 1) ~/ 2,
                                itemBuilder: (context, index) {
                                  final start = index * 2;
                                  final end = start + 2;
                                  final pageComments = _observeList.sublist(
                                    start,
                                    end > _observeList.length
                                        ? _observeList.length
                                        : end,
                                  );

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildCommentItem(pageComments[0]),
                                      if (pageComments.length > 1) ...[
                                        const VerticalDivider(
                                          width: 8,
                                          color: Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                        ),
                                        _buildCommentItem(pageComments[1]),
                                      ] else ...[
                                        Expanded(flex: 1, child: Container()),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}