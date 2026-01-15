import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dingbudaohang.dart';
import 'package:flutter_mall/utils/http_util.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'productdetails.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 仅保留kIsWeb用于注释说明，实际逻辑已移除Web端

// 商品数据模型
class Product {
  final String id;
  final String name;
  final String image;
  final String priceKRW;
  final String priceCNY;
  final String seller;
  final String sellerAvatar;
  final double rating;
  final int ratingCount;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.priceKRW,
    required this.priceCNY,
    required this.seller,
    required this.sellerAvatar,
    required this.rating,
    required this.ratingCount,
  });

  // 静态方法，通过State中的汇率计算价格
  static String calculateKRWPrice(double cnyPrice, double exchangeRate) {
    double krwPrice = cnyPrice * exchangeRate;
    // 舍去个位数：例如6034 → 6030，14354 → 14350
    int roundedPrice = (krwPrice / 10).floor() * 10;
    return roundedPrice.toString();
  }
  
  factory Product.fromJson(Map<String, dynamic> json, {double exchangeRate = 200.0}) {
    final double cnyPrice = double.tryParse(json['price'] ?? '0') ?? 0;
    final String krwPrice = calculateKRWPrice(cnyPrice, exchangeRate);

    return Product(
      id: json['item_id'].toString(),
      name: json['title'] ?? '',
      image: json['main_image_url'] ?? '',
      priceKRW: 'KRW $krwPrice',
      priceCNY: '(¥${cnyPrice.toStringAsFixed(2)})',
      seller: json['shop_name'] ?? '',
      sellerAvatar: '',
      rating: 4.5,
      ratingCount: json['inventory'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'Product('
        'id: $id, '
        'name: $name, '
        'image: $image, '
        'priceKRW: $priceKRW, '
        'priceCNY: $priceCNY, '
        'seller: $seller, '
        'rating: $rating, '
        'ratingCount: $ratingCount'
        ')';
  }
}

class SearchResultPage extends StatefulWidget {
  final String? keyword;
  final String? category;
  final List<Map<String, dynamic>>? imageSearchResults;

  const SearchResultPage({
    super.key,
    this.keyword,
    this.category,
    this.imageSearchResults,
  });

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  bool _isListView = true;
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final int _pageSize = 20;
  List<Product> _products = [];
  bool _hasMoreData = true;

  bool _isSearchLoading = false;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isImageSearchLoading = false;
  String _currentSort = "";
  bool _isImageSearch = false;
  String? _currentKeyword;
  bool _hasFetchedData = false;
  // 汇率：人民币兑韩元
  double _exchangeRate = 200.0; // 默认汇率，将在初始化时更新

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.keyword ?? widget.category,
    );
    _currentKeyword = widget.keyword ?? widget.category;
    _scrollController.addListener(_onScroll);
    _isImageSearch = false;
    _loadExchangeRate();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFetchedData) {
      if (widget.imageSearchResults != null && widget.imageSearchResults!.isNotEmpty) {
        // 如果有图片搜索结果，直接处理结果
        _processImageSearchResults();
      } else {
        // 否则执行正常的搜索
        _fetchSearchData(_currentKeyword ?? '');
      }
      _hasFetchedData = true;
    }
  }
  
  // 处理图片搜索结果
  void _processImageSearchResults() {
    if (widget.imageSearchResults == null || widget.imageSearchResults!.isEmpty) {
      return;
    }
    
    setState(() {
      _isImageSearch = true;
      _isSearchLoading = false;
      _products = widget.imageSearchResults!.map((json) => Product.fromJson(json, exchangeRate: _exchangeRate)).toList();
      _hasMoreData = false;
    });
  }
  
  // 加载汇率数据
  Future<void> _loadExchangeRate() async {
    try {
      // 调用汇率接口：人民币转韩元
      // currency=1（人民币）, benchmarkCurrency=2（韩元）, type=1
      Map<String, dynamic> params = {
        'currency': 2,
        'type': 1,
        'benchmarkCurrency': 1
      };
      Response response = await HttpUtil.get(searchRateUrl, queryParameters: params);
      if (response.statusCode == 200) {
        var data = response.data;
        if (data['code'] == 200 && data['data'] != null) {
          setState(() {
            _exchangeRate = data['data'].toDouble();
            print('汇率更新成功: $_exchangeRate');
          });
        }
      }
    } catch (e) {
      print('获取汇率失败: $e');
      // 失败时使用默认汇率
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSearchData(String searchKey) async {
    if (_isSearchLoading) return;
    setState(() {
      _isImageSearch = false;
      _currentKeyword = searchKey;
      _products = [];
    });

    final String currentLanguage = Localizations.localeOf(context).languageCode;
    final Map<String, dynamic> searchParams = {
      "keyword": searchKey.trim(),
      "sort": _currentSort,
      "pageNo": _currentPage.toString(),
      "pageSize": _pageSize.toString(),
      "filters": [],
      "language": currentLanguage,
    };

    setState(() => _isSearchLoading = true);

    try {
      final response = await HttpUtil.post(searchByKeyword, data: searchParams);
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final Map<String, dynamic> outerData = response.data['data'] ?? {};
        final List<dynamic> productJsonList = outerData['data'] ?? [];

        final List<Product> newProducts = productJsonList
            .map((json) => Product.fromJson(json, exchangeRate: _exchangeRate))
            .toList();

        setState(() {
          if (_isRefreshing) {
            _products = newProducts;
          } else if (_isLoadingMore) {
            _products.addAll(newProducts);
          } else {
            _products = newProducts;
          }
          _hasMoreData = newProducts.length >= _pageSize;
          _isRefreshing = false;
          _isLoadingMore = false;
        });
      } else {
        String errorText = AppLocalizations.of(context)!.translate("network_error");
        throw Exception(response.data['msg'] ?? errorText);
      }
    } catch (e) {
      print("搜索接口失败：$e");
      String loadFailText = AppLocalizations.of(context)!.translate("load_data_fail");
      loadFailText = loadFailText.replaceAll("%s", e.toString().substring(0, 50));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loadFailText),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isRefreshing = false;
        _isLoadingMore = false;
      });
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    if (_isSearchLoading || !_hasMoreData) return;
    setState(() {
      _isRefreshing = true;
      _currentPage = 1;
    });
    await _fetchSearchData(_currentKeyword ?? '');
  }

  Future<void> _loadMoreData() async {
    if (_isRefreshing || _isLoadingMore || !_hasMoreData) return;
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchSearchData(_currentKeyword ?? '');
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isRefreshing &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(
                AppLocalizations.of(context)!.translate("select_image_source"),
                style: TextStyle(fontSize: 16.sp)
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                AppLocalizations.of(context)!.translate("image_source_gallery")
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                AppLocalizations.of(context)!.translate("image_source_camera")
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.translate("cancel"),
                textAlign: TextAlign.center
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null) return;
      await _uploadImageToTaobao(pickedFile);
    } catch (e) {
      print("图片选择失败：$e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.translate("image_pick_fail")
          )
        )
      );
    }
  }

  // 仅保留移动端图片上传逻辑（移除Web端代码）
  Future<void> _uploadImageToTaobao(XFile imageFile) async {
    setState(() => _isImageSearchLoading = true);
    try {
      // 移动端直接读取字节数据
      final List<int> imageBytes = await imageFile.readAsBytes();
      print("移动端图片读取成功，字节长度：${imageBytes.length}");

      final String base64Image = base64Encode(imageBytes);
      final Response response = await HttpUtil.post(
        taobaoimg,
        data: {"imageBase64": base64Image},
        options: Options(contentType: "application/json", sendTimeout: const Duration(seconds: 10)),
      );

      if (response.data["code"] == 200) {
        await _searchByImage(response.data["msg"]);
      } else {
        String errorText = AppLocalizations.of(context)!.translate("network_error");
        throw Exception(response.data["msg"] ?? errorText);
      }
    } catch (e) {
      print("图片上传失败：$e");
      String uploadFailText = AppLocalizations.of(context)!.translate("image_upload_fail");
      uploadFailText = uploadFailText.replaceAll("%s", e.toString().substring(0, 80));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(uploadFailText))
      );
    } finally {
      if (mounted) setState(() => _isImageSearchLoading = false);
    }
  }

  Future<void> _searchByImage(String imageId) async {
    setState(() => _isImageSearchLoading = true);
    try {
      final String currentLanguage = Localizations.localeOf(context).languageCode;
      final Response response = await HttpUtil.post(
        searchByImage,
        data: {"imageId": imageId, "language": currentLanguage},
      );

      if (response.data["code"] == 200) {
        final Map<String, dynamic> outerData = response.data['data'] ?? {};
        final List<dynamic> productJsonList = outerData['data'] ?? [];

        final List<Product> newProducts = productJsonList
            .map((json) => Product.fromJson(json, exchangeRate: _exchangeRate))
            .toList();

        setState(() {
          _products = newProducts;
          _currentPage = 1;
          _hasMoreData = newProducts.length >= _pageSize;
          _isImageSearch = true;
          _searchController.clear();
          _currentKeyword = null;
        });

        String searchSuccessText = AppLocalizations.of(context)!.translate("image_search_success");
        searchSuccessText = searchSuccessText.replaceAll("%s", newProducts.length.toString());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(searchSuccessText))
        );
      } else {
        String errorText = AppLocalizations.of(context)!.translate("network_error");
        throw Exception(response.data["msg"] ?? errorText);
      }
    } catch (e) {
      print("图片搜索失败：$e");
      String searchFailText = AppLocalizations.of(context)!.translate("image_search_fail");
      searchFailText = searchFailText.replaceAll("%s", e.toString().substring(0, 50));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(searchFailText))
      );
    } finally {
      if (mounted) setState(() => _isImageSearchLoading = false);
    }
  }

  Widget _buildGridItem(Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetails(
              id: product.id,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1.w, blurRadius: 2.w)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 确保容器高度适应内容
          children: [
            Container(
              width: double.infinity,
              height: 130.h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(8.r))),
              child: Image.network(
                product.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.error, size: 24.w)),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Center(child: CircularProgressIndicator(strokeWidth: 1.w)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(6.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // 确保容器高度适应内容
                children: [
                  // 商品名称
                  Text(
                    product.name,
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  
                  // 价格和店铺信息水平布局
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 价格信息
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.priceKRW,
                            style: TextStyle(fontSize: 11.sp, color: Colors.black, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            product.priceCNY,
                            style: TextStyle(fontSize: 9.sp, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      
                      // 店铺名称
                      SizedBox(
                        width: 70.w,
                        child: Text(
                          product.seller,
                          style: TextStyle(fontSize: 10.sp, color: Colors.black87, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(Product product) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetails(
              id: product.id,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1.w, blurRadius: 2.w)],
        ),
        child: Row(
          children: [
            Container(
              width: 100.w,
              height: 100.h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: Colors.grey.shade100, width: 1.w),
              ),
              child: Image.network(
                product.image,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color:Colors.grey.shade50,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 1.w)),
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.seller,
                    style: TextStyle(fontSize: 14.sp, color: Colors.black87, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    product.name,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.priceKRW,
                        style: TextStyle(fontSize: 16.sp, color: Colors.black, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        product.priceCNY,
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTag() {
    String filterPrefix = AppLocalizations.of(context)!.translate("filter_prefix");
    String allProducts = AppLocalizations.of(context)!.translate("all_products");
    
    String filterText = filterPrefix;
    if (_isImageSearch) {
      filterText += allProducts;
    } else {
      if (_currentKeyword?.isNotEmpty ?? false) {
        filterText += _currentKeyword!;
      } else if (widget.category?.isNotEmpty ?? false) {
        filterText += widget.category!;
      } else {
        filterText += allProducts;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      alignment: Alignment.centerLeft,
      child: Text(
        filterText,
        style: TextStyle(color: Colors.red, fontSize: 14.sp),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return _isLoadingMore
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.w)),
          )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black87, size: 24.w),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(22.r),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 12.w),
                              Container(
                                width: 24.w,
                                height: 24.h,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Center(
                                  child: Text(
                                    '淘',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!.translate("input_search_hint"),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: TextStyle(fontSize: 14.sp),
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty) {
                                      _currentPage = 1;
                                      _fetchSearchData(value);
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: _isImageSearchLoading ? null : _showImageSourceActionSheet,
                                child: Container(
                                  padding: EdgeInsets.all(8.w),
                                  child: Icon(Icons.camera_alt, color: Colors.grey, size: 24.w),
                                ),
                              ),
                              GestureDetector(
                                onTap: _isSearchLoading
                                    ? null
                                    : () {
                                        final keyword = _searchController.text;
                                        if (keyword.trim().isNotEmpty) {
                                          _currentPage = 1;
                                          _fetchSearchData(keyword);
                                        }
                                      },
                                child: Container(
                                  padding: EdgeInsets.all(8.w),
                                  child: Icon(Icons.search, color: Colors.grey, size: 24.w),
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      IconButton(
                        icon: Icon(
                          _isListView ? Icons.grid_view : Icons.list,
                          color: Colors.black87,
                          size: 24.w,
                        ),
                        onPressed: () => setState(() => _isListView = !_isListView),
                      ),
                    ],
                  ),
                ),
                if (!_isImageSearch)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_currentSort == "SALE_QTY_ASC") {
                                _currentSort = "SALE_QTY_DESC";
                              } else if (_currentSort == "SALE_QTY_DESC") {
                                _currentSort = "";
                              } else {
                                _currentSort = "SALE_QTY_ASC";
                              }
                              _currentPage = 1;
                              _fetchSearchData(_currentKeyword ?? '');
                            });
                          },
                          child: Text(
                            AppLocalizations.of(context)!.translate("sort_sales"),
                            style: TextStyle(
                              color: _currentSort.startsWith("SALE_QTY") ? Colors.red : Colors.black87,
                              fontSize: 14.sp,
                              fontWeight: _currentSort.startsWith("SALE_QTY") ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        SizedBox(width: 20.w),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_currentSort == "PRICE_ASC") {
                                _currentSort = "PRICE_DESC";
                              } else if (_currentSort == "PRICE_DESC") {
                                _currentSort = "";
                              } else {
                                _currentSort = "PRICE_ASC";
                              }
                              _currentPage = 1;
                              _fetchSearchData(_currentKeyword ?? '');
                            });
                          },
                          child: Text(
                            AppLocalizations.of(context)!.translate("sort_price"),
                            style: TextStyle(
                              color: _currentSort.startsWith("PRICE") ? Colors.red : Colors.black87,
                              fontSize: 14.sp,
                              fontWeight: _currentSort.startsWith("PRICE") ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              backgroundColor: Colors.white,
              child: _products.isEmpty
                  ? _isSearchLoading || _isImageSearchLoading
                      ? Center(child: CircularProgressIndicator(strokeWidth: 2.w))
                      : Center(child: Text(AppLocalizations.of(context)!.translate("no_product_data")))
                  : _isListView
                      ? ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(vertical: 0),
                          itemCount: 1 + _products.length + 1,
                          itemBuilder: (_, index) {
                            if (index == 0) return _buildFilterTag();
                            if (index <= _products.length) {
                              return _buildListItem(_products[index - 1]);
                            }
                            return _buildLoadMoreIndicator();
                          },
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(vertical: 0),
                          children: [
                            _buildFilterTag(),
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 8.w,
                                mainAxisSpacing: 8.h,
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              itemCount: _products.length,
                              itemBuilder: (_, index) => _buildGridItem(_products[index]),
                            ),
                            _buildLoadMoreIndicator(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}