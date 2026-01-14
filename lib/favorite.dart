import 'package:flutter/material.dart';
import 'dingbudaohang.dart';
import './config/service_url.dart';
import './utils/http_util.dart';
import 'productdetails.dart';
import 'self_product_details.dart';
import 'app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 自营商品列表

/// 商品规格信息模型
class ProductSpec {
  int skuId;
  int quantity;
  int price;
  int promotionPrice;
  String? picUrl;
  List<String> properties;
  int couponPrice;

  ProductSpec({
    required this.skuId,
    required this.quantity,
    required this.price,
    required this.promotionPrice,
    this.picUrl,
    required this.properties,
    required this.couponPrice,
  });

  factory ProductSpec.fromJson(Map<String, dynamic> json) {
    return ProductSpec(
      skuId: json['sku_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0,
      promotionPrice: json['promotion_price'] ?? 0,
      picUrl: json['pic_url'],
      properties: List<String>.from(json['properties'] ?? []),
      couponPrice: json['coupon_price'] ?? 0,
    );
  }
}

/// 自营商品项模型
class CollectItem {
  String productId; // 商品ID，改为String类型确保可以直接用于路由跳转
  String productName;
  String productNameEn;
  String productNameCn;
  String picture;
  String video;
  String price;
  String pricePlus;
  String plus;
  String push;
  String productType;
  String productCatelogId;
  String unit;
  String productDetail;
  String productKeyword;
  int pointsId;
  int activeId;
  int couponId;
  int minPayNum;
  int houseNum;
  String beforeProduct;
  int payNum;
  String skuType;

  CollectItem({
    required this.productId,
    required this.productName,
    required this.productNameEn,
    required this.productNameCn,
    required this.picture,
    required this.video,
    required this.price,
    required this.pricePlus,
    required this.plus,
    required this.push,
    required this.productType,
    required this.productCatelogId,
    required this.unit,
    required this.productDetail,
    required this.productKeyword,
    required this.pointsId,
    required this.activeId,
    required this.couponId,
    required this.minPayNum,
    required this.houseNum,
    required this.beforeProduct,
    required this.payNum,
    required this.skuType,
  });

  factory CollectItem.fromJson(Map<String, dynamic> json) {
    return CollectItem(
      productId: json['productId']?.toString() ?? '', // 确保productId为String类型
      productName: json['productName'] ?? '',
      productNameEn: json['productNameEn'] ?? '',
      productNameCn: json['productNameCn'] ?? '',
      picture: json['picture'] ?? '',
      video: json['video'] ?? '',
      price: json['price'] ?? '0.00',
      pricePlus: json['pricePlus'] ?? '0.00',
      plus: json['plus'] ?? '1',
      push: json['push'] ?? '1',
      productType: json['productType'] ?? '1',
      productCatelogId: json['productCatelogId'] ?? '',
      unit: json['unit'] ?? '',
      productDetail: json['productDetail'] ?? '',
      productKeyword: json['productKeyword'] ?? '',
      pointsId: json['pointsId'] ?? 0,
      activeId: json['activeId'] ?? 0,
      couponId: json['couponId'] ?? 0,
      minPayNum: json['minPayNum'] ?? 0,
      houseNum: json['houseNum'] ?? 0,
      beforeProduct: json['beforeProduct'] ?? '1',
      payNum: json['payNum'] ?? 0,
      skuType: json['skuType'] ?? '1',
    );
  }
}

/// 收藏列表响应模型
class CollectListResponse {
  int total;
  List<CollectItem> rows;
  int code;
  String msg;

  CollectListResponse({
    required this.total,
    required this.rows,
    required this.code,
    required this.msg,
  });

  factory CollectListResponse.fromJson(Map<String, dynamic> json) {
    var rowsList = json['rows'] as List? ?? [];
    List<CollectItem> items = rowsList.map((item) => CollectItem.fromJson(item)).toList();

    return CollectListResponse(
      total: json['total'] ?? 0,
      rows: items,
      code: json['code'] ?? 0,
      msg: json['msg'] ?? '',
    );
  }
}

/// 收藏页面
class Favorite extends StatefulWidget {
  const Favorite({super.key});

  @override
  State<Favorite> createState() => _Favorite();
}

class _Favorite extends State<Favorite> {
  List<CollectItem> collectList = [];
  int totalItems = 0;
  int currentPage = 1;
  int pageSize = 20;
  bool isLoading = false;
  bool hasMore = true;
  bool isRefreshing = false;
  bool initialLoadCompleted = false; // 新增状态：初始加载是否完成
  double krwExchangeRate = 0.0; // 韩元汇率
  bool isLoadingRate = false; // 汇率加载状态
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 初始加载汇率和数据
    loadExchangeRate();
    loadCollectList(refresh: true);
    
    // 设置滚动监听，实现上拉加载更多
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !isLoading && hasMore) {
        // 滚动到底部且有更多数据时加载下一页
        loadCollectList(refresh: false);
      }
    });
  }
  
  /// 加载汇率
  Future<void> loadExchangeRate() async {
    if (isLoadingRate) return;
    
    setState(() {
      isLoadingRate = true;
    });
    
    try {
      final response = await HttpUtil.get(
        searchRateUrl,
        queryParameters: {
          'currency': 2,  // 韩元
          'type': 1,
          'benchmarkCurrency': 1  // 人民币
        },
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        setState(() {
          krwExchangeRate = double.tryParse(response.data['data']?.toString() ?? '0.0') ?? 0.0;
        });
      }
    } catch (e) {
      // 汇率加载失败，使用默认值
      setState(() {
        krwExchangeRate = 170.0; // 设置默认汇率
      });
    } finally {
      setState(() {
        isLoadingRate = false;
      });
    }
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }



  /// 加载收藏列表
  Future<void> loadCollectList({required bool refresh}) async {
    if (isLoading || (!refresh && !hasMore)) return;

    setState(() {
      isLoading = true;
      if (refresh) {
        isRefreshing = true;
        currentPage = 1;
        collectList.clear();
      }
    });

    try {
       final response = await HttpUtil.get(
        selfProductListUrl,
        queryParameters: {
          'pageSize': pageSize,
          'pageNum': currentPage,
        },
      );
      
      if (response.data['code'] == 200) {
        CollectListResponse data = CollectListResponse.fromJson(response.data);
        
        setState(() {
          collectList.addAll(data.rows);
          totalItems = data.total;
          currentPage++;
          hasMore = collectList.length < totalItems;
          initialLoadCompleted = true; // 标记初始加载完成
        });
      }
    } catch (e) {
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('load_failed') ?? '加载失败，请稍后重试')),
      );
      setState(() {
        initialLoadCompleted = true; // 即使失败也标记为完成，让用户可以看到空状态并重新加载
      });
    } finally {
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  /// 下拉刷新回调
  Future<void> onRefresh() async {
    await loadCollectList(refresh: true);
  }

  /// 渲染底部加载状态
  Widget _buildFooter() {
    if (!isLoading || isRefreshing) return Container();
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10.w),
          Text(
            AppLocalizations.of(context)?.translate('loading') ?? '加载中...',
            style: TextStyle(fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  /// 渲染空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, 
              size: 60.w, 
              color: Colors.grey),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)?.translate('no_collect_items') ?? '暂无收藏商品',
            style: TextStyle(fontSize: 16.sp),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () => onRefresh(),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 10.h,
              ),
            ),
            child: Text(
              AppLocalizations.of(context)?.translate('reload') ?? '重新加载',
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  /// 计算韩元价格
  String calculateKrwPrice(String cnyPrice) {
    try {
      double price = double.parse(cnyPrice);
      double krwPrice = price * krwExchangeRate;
      // 去除个位数（向下取整到十位数）
      double roundedPrice = (krwPrice / 10).floor() * 10;
      return roundedPrice.toStringAsFixed(0);
    } catch (e) {
      return '0';
    }
  }
  
  /// 渲染商品项
  Widget _buildProductItem(CollectItem item) {
    double imageSize = 100.w;
    
    // 处理价格显示逻辑：如果会员价大于0，优先显示会员价，否则显示原价
    String displayPrice = item.price;
    bool isMemberPrice = false;
    
    try {
      double pricePlus = double.parse(item.pricePlus);
      if (pricePlus > 0) {
        displayPrice = item.pricePlus;
        isMemberPrice = true;
      }
    } catch (e) {
      // 解析价格失败时，使用原价
    }
    
    // 获取主图URL（从图片列表中取第一个）
    String mainImageUrl = item.picture;
    if (item.picture.contains(',')) {
      mainImageUrl = item.picture.split(',')[0];
    }
    
    return GestureDetector(
      onTap: () {
        // 根据商品类型跳转到不同的详情页面
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) {
              // 如果是自营商品，跳转到新的自营商品详情页面
              return SelfProductDetails(id: item.productId.toString());
            },
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(
          left: 10.w, 
          right: 10.w, 
          bottom: 10.w
        ),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧商品图片
            Container(
              width: imageSize,
              height: imageSize,
              margin: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: mainImageUrl.isNotEmpty
                  ? Image.network(
                      mainImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Icon(Icons.image_not_supported));
                      },
                    )
                  : Center(child: Icon(Icons.image_not_supported)),
            ),
            
            // 右侧信息展示区
            Expanded(
              child: Container(
                padding: EdgeInsets.all(10.w),
                height: imageSize + 20.w, // 与图片高度保持一致
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 商品名称（中文）
                    Text(
                      item.productNameCn,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // 商品价格
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 韩元价格
                        Text(
                          '₩${calculateKrwPrice(displayPrice)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        // 人民币价格
                        Row(
                          children: [
                            Text(
                              '¥$displayPrice',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            if (isMemberPrice) ...[
                              SizedBox(width: 5.w),
                              Text(
                                '¥${item.price}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Container(
        color: Color(int.parse('f5f5f5', radix: 16)).withAlpha(255),
        width: MediaQuery.of(context).size.width,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: initialLoadCompleted && collectList.isEmpty && !isLoading
              ? _buildEmptyState() // 只有当初始加载完成且列表为空且不在加载中时才显示空状态
              : collectList.isEmpty && isLoading
                  ? Center(child: CircularProgressIndicator()) // 初始加载时显示加载指示器
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      itemCount: collectList.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == collectList.length) {
                          return _buildFooter();
                        }
                        // 渲染商品项
                        return _buildProductItem(collectList[index]);
                      },
                    ),
        ),
      ),
    );
  }
}

