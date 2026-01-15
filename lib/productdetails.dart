import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'dingbudaohang.dart';
import './config/service_url.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './app_localizations.dart';
import 'review.dart';
import 'userreviews.dart';
import 'cartadd.dart';
import 'utils/http_util.dart';

// 商品详情页
class ProductComment {
  final int observeId;
  final int memberId; // 用户ID（用于跳转）
  final String info; // 评论内容
  final String nickname; // 显示用户昵称
  final String sec; // 原始规格JSON字符串
  final String star; // 评星（1-5）
  final String? pictureUrl; // 评价图片
  final String goodObserve; // 是否优质评论（1否 2是）
  final String obsDate; // 评价时间
  final String? memberAvator; // 用户头像

  // 解析后的规格名称
  String get parsedSec {
    try {
      if (sec.isEmpty) return "";
      Map<String, dynamic> secJson = jsonDecode(sec);
      List<dynamic> properties = secJson['properties'] ?? [];
      if (properties.isNotEmpty) {
        return properties[0]['value_name'] ?? "";
      }
      return "";
    } catch (e) {
      debugPrint("解析规格失败：$e");
      return "规格信息";
    }
  }

  ProductComment({
    required this.observeId,
    required this.memberId,
    required this.info,
    required this.nickname,
    required this.sec,
    required this.star,
    this.pictureUrl,
    required this.goodObserve,
    required this.obsDate,
    this.memberAvator,
  });

  factory ProductComment.fromJson(Map<String, dynamic> json) {
    return ProductComment(
      observeId: json['observeId'] ?? 0,
      memberId: json['memberId'] ?? 0,
      info: json['info'] ?? '',
      nickname: json['nickname'] ?? '',
      sec: json['sec'] ?? '',
      star: json['star'] ?? '0',
      pictureUrl: json['pictureUrl'],
      goodObserve: json['goodObserve'] ?? '1',
      obsDate: json['obsDate'] ?? '',
      memberAvator: json['memberAvator'],
    );
  }
}

class ProductDetails extends StatefulWidget {
 final String id; // 商品ID

const ProductDetails({super.key, required this.id});

  @override
  State<ProductDetails> createState() => _ProductDetailspayState();
}

class _ProductDetailspayState extends State<ProductDetails> {
  bool isFavorite = false;
  Map<String, dynamic>? _productDetailData;
  String? _productId; // 对应item_id
  String? _mpId; // 商品MPID（需嵌入sec参数）
  Map<String, String> _skuIdToMpSkuId = {}; // sku_id -> mp_skuId 映射（从skList提取）
  
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;
  String _productTitle = "";
  String _shopName = "";
  String? _cnTitle;
  String? _enTitle;
  String? _krTitle;

  int? _shopId;
  String? _wangwangUrl;
  String? _wangwangTalkUrl;
  int _minNum = 0;

  // 价格变量
  double _mainOriginalPriceKRW = 0.0;
  double? _mainPromotionPriceKRW;
  double _mainOriginalPriceCNY = 0.0;
  double? _mainPromotionPriceCNY;
  double _originalPriceKRW = 0.0;
  double? _promotionPriceKRW;
  double _originalPriceCNY = 0.0;
  double? _promotionPriceCNY;
  
  // 汇率变量
  double? _exchangeRate; // 汇率，通过API获取，初始为null

  String _description = "";

  // SKU相关
  List<dynamic> _skuList = [];
  Map<String, List<String>> _specGroups = {};
  Map<String, String> _selectedSpecs = {};
  dynamic _selectedSku; // 选中的SKU将包含mp_skuId
  List<String> _skuFeatureTexts = [];

  // 多语言映射
  final Map<String, Map<String, String>> _propIdToLanguages = {};
  final Map<String, Map<String, String>> _valueIdToLanguages = {};

  // 评论数据
  List<ProductComment> _realComments = [];
  bool _isCommentsLoading = true;
  String? _commentError;

  String currentLanguage = "中文";

  @override
  void initState() {
    super.initState();
    _loadExchangeRate();
    _fetchProductDetail();
  }
  
  // 加载汇率
  void _loadExchangeRate() async {
    try {
      final response = await HttpUtil.get(
        searchRateUrl,
        queryParameters: {
          'currency': 2,  // 根据search.dart中的修改，这里应该是2表示韩元
          'type': 1,
          'benchmarkCurrency': 1  // 1表示人民币
        },
      );
      
      if (response.data['code'] == 200) {
        final rateData = response.data['data'];
        if (rateData != null) {
          double newRate = rateData.toDouble();
          setState(() {
            _exchangeRate = newRate;
            // 汇率更新后，重新计算韩元价格
            _mainOriginalPriceKRW = _calculateKRWPrice(_mainOriginalPriceCNY);
            _mainPromotionPriceKRW = _mainPromotionPriceCNY != null
                ? _calculateKRWPrice(_mainPromotionPriceCNY!)
                : null;
            _originalPriceKRW = _calculateKRWPrice(_originalPriceCNY);
            _promotionPriceKRW = _promotionPriceCNY != null
                ? _calculateKRWPrice(_promotionPriceCNY!)
                : null;
          });
        }
      }
    } catch (e) {
      debugPrint("汇率查询失败：$e");
    }
  }
  
  // 计算韩元价格
  double _calculateKRWPrice(double cnyPrice) {
    // 只有当汇率不为null时才计算韩元价格
    return _exchangeRate != null ? cnyPrice * _exchangeRate! : 0.0;
  }

  String _getLangKey() {
    switch (currentLanguage) {
      case "中文":
        return "zh";
      case "English":
        return "en";
      case "한국어":
        return "ko";
      default:
        return "zh";
    }
  }

  String _fixImageUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'https://$url';
  }

  String _getCurrentTitle() {
    switch (currentLanguage) {
      case "中文":
        return _cnTitle ?? _productTitle;
      case "English":
        return _enTitle ?? _cnTitle ?? _productTitle;
      case "한국어":
        return _krTitle ?? _cnTitle ?? _productTitle;
      default:
        return _productTitle;
    }
  }

  String _getSkuListJson() {
    try {
      return jsonEncode(_skuList);
    } catch (e) {
      debugPrint("SKU列表JSON序列化失败: $e");
      return "[]";
    }
  }

  void _toggleFavorite() async {
    if (_productId == null || _productId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('product_info_missing_operate') ?? '商品信息缺失，操作失败'
          )
        )
      );
      return;
    }

    final bool wasFavorite = isFavorite;
    setState(() => isFavorite = !isFavorite);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text(
                AppLocalizations.of(context)?.translate('please_login') ?? '请先登录'
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    AppLocalizations.of(context)?.translate('ok') ?? '确定'
                  )
                )
              ],
            );
          }
        );
        setState(() => isFavorite = wasFavorite);
        return;
      }

      if (!wasFavorite) {
        final collectParams = {
          "productId": int.tryParse(_productId!) ?? 0,
          "productName": _krTitle ?? _productTitle ?? "",
          "productNameCn": _cnTitle ?? _productTitle ?? "",
          "productNameEn": _enTitle ?? _productTitle ?? "",
          "shopId": _shopId ?? 0,
          "shopName": _shopName ?? "",
          "wangwangUrl": _wangwangUrl ?? "",
          "productUrl": _imageUrls.isNotEmpty ? _imageUrls[0] : "",
          "minNum": _minNum,
          "sec": _getSkuListJson(),
          "wangwangTalkUrl": _wangwangTalkUrl ?? "",
          "selfSupport": 1,
        };

        final response = await HttpUtil.post(
          getcollect,
          data: collectParams,
        );

        if (response.data['code'] != 200 && !response.data['success']) {
          throw Exception(response.data['msg'] ?? '收藏失败');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('collect_success') ?? '收藏成功'
            )
          )
        );
      } else {
        String cancelUrl = reamcollect.replaceAll(RegExp(r'\{productId\}'), _productId!);
        final response = await HttpUtil.del(cancelUrl);

        if (response.data['code'] != 200 && !response.data['success']) {
          throw Exception(response.data['msg'] ?? '取消收藏失败');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('cancel_collect_success') ?? '取消收藏成功'
            )
          )
        );
      }
    } catch (e) {
      setState(() => isFavorite = wasFavorite);
      debugPrint('收藏操作异常：$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)?.translate('operation_failed') ?? '操作失败：'}${e.toString()}'
          )
        )
      );
    }
  }

  void _parseChineseSku(List<dynamic> skuList, Map<String, String> skuIdToMpSkuId) {
    _skuList.clear();
    for (var sku in skuList) {
      String? skuId = sku['sku_id']?.toString();
      if (skuId != null && skuIdToMpSkuId.containsKey(skuId)) {
        sku['mp_skuId'] = skuIdToMpSkuId[skuId];
      }

      List<dynamic> properties = sku['properties'] ?? [];
      List<dynamic> newProperties = [];

      for (var prop in properties) {
        String propId = prop['prop_id'].toString();
        String propName = prop['prop_name'] ?? '';
        String valueId = prop['value_id'].toString();
        String valueName = prop['value_name'] ?? '';

        _propIdToLanguages[propId] = {
          "zh": propName,
          "en": propName,
          "ko": propName,
        };

        String valueKey = "$propId-$valueId";
        _valueIdToLanguages[valueKey] = {
          "zh": valueName,
          "en": valueName,
          "ko": valueName,
        };

        newProperties.add({
          ...prop,
          "zhName": propName,
          "enName": propName,
          "koName": propName,
          "zhValue": valueName,
          "enValue": valueName,
          "koValue": valueName,
        });
      }

      _skuList.add({...sku, "properties": newProperties});
    }
  }

  void _mergeEnglishTranslations(List<dynamic> enSkuProperties) {
    for (var skuProp in enSkuProperties) {
      List<dynamic> properties = skuProp['properties'] ?? [];
      for (var prop in properties) {
        String propId = prop['prop_id'].toString();
        String enPropName = prop['prop_name'] ?? '';
        String valueId = prop['value_id'].toString();
        String enValueName = prop['value_name'] ?? '';

        if (_propIdToLanguages.containsKey(propId)) {
          _propIdToLanguages[propId]!['en'] = enPropName;
        }

        String valueKey = "$propId-$valueId";
        if (_valueIdToLanguages.containsKey(valueKey)) {
          _valueIdToLanguages[valueKey]!['en'] = enValueName;
        }
      }
    }

    _updateSkuListWithLanguage("en");
  }

  void _mergeKoreanTranslations(List<dynamic> koSkuProperties) {
    for (var skuProp in koSkuProperties) {
      List<dynamic> properties = skuProp['properties'] ?? [];
      for (var prop in properties) {
        String propId = prop['prop_id'].toString();
        String koPropName = prop['prop_name'] ?? '';
        String valueId = prop['value_id'].toString();
        String koValueName = prop['value_name'] ?? '';

        if (_propIdToLanguages.containsKey(propId)) {
          _propIdToLanguages[propId]!['ko'] = koPropName;
        }

        String valueKey = "$propId-$valueId";
        if (_valueIdToLanguages.containsKey(valueKey)) {
          _valueIdToLanguages[valueKey]!['ko'] = koValueName;
        }
      }
    }
  
    _updateSkuListWithLanguage("ko");
  }

  void _updateSkuListWithLanguage(String lang) {
    for (var sku in _skuList) {
      List<dynamic> properties = sku['properties'] ?? [];
      for (var prop in properties) {
        String propId = prop['prop_id'].toString();
        String valueId = prop['value_id'].toString();
        String valueKey = "$propId-$valueId";

        if (_propIdToLanguages.containsKey(propId)) {
          prop["${lang}Name"] = _propIdToLanguages[propId]![lang] ?? prop["${lang}Name"];
        }

        if (_valueIdToLanguages.containsKey(valueKey)) {
          prop["${lang}Value"] = _valueIdToLanguages[valueKey]![lang] ?? prop["${lang}Value"];
        }
      }
    }
  }

  void _generateSpecsByLanguage() {
    String lang = _getLangKey();
    Map<String, List<String>> newSpecGroups = {};
    List<String> newFeatureTexts = [];

    for (var sku in _skuList) {
      List<dynamic> properties = sku['properties'] ?? [];
      if (properties.isEmpty) continue;

      String firstValue = properties[0]["${lang}Value"] ?? '';
      if (firstValue.isNotEmpty && !newFeatureTexts.contains(firstValue)) {
        newFeatureTexts.add(firstValue);
      }

      for (var prop in properties) {
        String propName = prop["${lang}Name"] ?? '';
        String valueName = prop["${lang}Value"] ?? '';

        if (propName.isNotEmpty && valueName.isNotEmpty) {
          if (!newSpecGroups.containsKey(propName)) {
            newSpecGroups[propName] = [];
          }
          if (!newSpecGroups[propName]!.contains(valueName)) {
            newSpecGroups[propName]!.add(valueName);
          }
        }
      }
    }

    setState(() {
      _specGroups = newSpecGroups;
      _skuFeatureTexts = newFeatureTexts;
    });
  }

  void _initSelectedSpecs() {
    setState(() {
      _selectedSpecs.clear();
      _specGroups.forEach((key, values) {
        if (values.isNotEmpty) {
          _selectedSpecs[key] = values.first;
        }
      });
      _updateSelectedSku();
    });
  }

  void _updateSelectedSku() {
    if (_skuList.isEmpty || _selectedSpecs.isEmpty) return;

    String lang = _getLangKey();
    for (var sku in _skuList) {
      List<dynamic> properties = sku['properties'] ?? [];
      bool isMatch = true;

      for (var entry in _selectedSpecs.entries) {
        String targetPropName = entry.key;
        String targetValueName = entry.value;
        bool propMatch = false;

        for (var prop in properties) {
          String propName = prop["${lang}Name"] ?? '';
          String valueName = prop["${lang}Value"] ?? '';

          if (propName == targetPropName && valueName == targetValueName) {
            propMatch = true;
            break;
          }
        }

        if (!propMatch) {
          isMatch = false;
          break;
        }
      }

      if (isMatch) {
        setState(() {
          _selectedSku = sku;
          // 价格单位是分，先除以100转换为人民币
          _originalPriceCNY = (sku['price'] as num? ?? 0) / 100.0;
          _promotionPriceCNY = (sku['promotion_price'] as num?) != null
              ? (sku['promotion_price'] as num?)! / 100.0
              : null;
          // 只有当汇率不为null时才计算韩元价格
          _originalPriceKRW = _exchangeRate != null ? _originalPriceCNY * _exchangeRate! : 0.0;
          _promotionPriceKRW = _promotionPriceCNY != null && _exchangeRate != null
              ? _promotionPriceCNY! * _exchangeRate!
              : null;
        });
        break;
      }
    }
  }

  void _fetchProductDetail() async {
    try {
      final initialItemId = widget.id;
      final response = await HttpUtil.post(
          getProductDetail,
          data: {"itemId": initialItemId}, 
        );

      setState(() {
        _productDetailData = response.data;
        final detailData = _productDetailData?['data']?['data'];
        if (detailData != null) {
          isFavorite = detailData['collected'] ?? false;

          _mpId = detailData['mpId']?.toString(); // 商品MPID（需嵌入sec）
          List<dynamic> skList = detailData['skList'] as List? ?? [];
          for (var sk in skList) {
            String? skuId = sk['sku_id']?.toString();
            String? mpSkuId = sk['mp_skuId']?.toString();
            if (skuId != null && mpSkuId != null) {
              _skuIdToMpSkuId[skuId] = mpSkuId;
            }
          }

          _productId = detailData['item_id']?.toString(); // 对应item_id
          _cnTitle = detailData['title']?.toString();
          _enTitle = detailData['multiLanguageInfoEN']?['title']?.toString();
          _krTitle = detailData['multi_language_info']?['title']?.toString();
          _productTitle = _getCurrentTitle() ?? "商品标题";

          _shopId = detailData['shop_id'] as int?;
          _shopName = detailData['shop_name']?.toString() ?? "未知店铺";
          _wangwangUrl = detailData['wangwang_url']?.toString() ?? "";
          _wangwangTalkUrl = detailData['wangwang_talk_url']?.toString() ?? "";
          _minNum = detailData['min_num'] as int? ?? 0;

          final picUrls = detailData['pic_urls'] as List?;
          if (picUrls?.isNotEmpty == true) {
            _imageUrls = picUrls!.map((url) => _fixImageUrl(url.toString())).toList();
          }

          // 价格解析 - 价格单位是分，先除以100转换为人民币
          final priceNumCNY = (detailData['price'] as num? ?? 0) / 100.0;
          final promotionPriceNumCNY = (detailData['promotion_price'] as num?) != null
              ? (detailData['promotion_price'] as num?)! / 100.0
              : null;

          _mainOriginalPriceCNY = priceNumCNY;
          _mainPromotionPriceCNY = promotionPriceNumCNY;
          _mainOriginalPriceKRW = _calculateKRWPrice(priceNumCNY);
          _mainPromotionPriceKRW = promotionPriceNumCNY != null
              ? _calculateKRWPrice(promotionPriceNumCNY)
              : null;

          _originalPriceKRW = _mainOriginalPriceKRW;
          _promotionPriceKRW = _mainPromotionPriceKRW;
          _originalPriceCNY = _mainOriginalPriceCNY;
          _promotionPriceCNY = _mainPromotionPriceCNY;

          // 解析SKU
          List<dynamic> chineseSkuList = detailData['skList'] as List? ?? [];
          _parseChineseSku(chineseSkuList, _skuIdToMpSkuId);

          // 合并英文翻译
          final enLangData = detailData['multiLanguageInfoEN'];
          if (enLangData != null) {
            _mergeEnglishTranslations(enLangData['sku_properties'] as List? ?? []);
          }

          // 合并韩文翻译
          final koLangData = detailData['multi_language_info'];
          if (koLangData != null) {
            _mergeKoreanTranslations(koLangData['sku_properties'] as List? ?? []);
          }

          // 生成规格组
          _generateSpecsByLanguage();

          // 初始化选中状态
          if (_specGroups.isNotEmpty) {
            _initSelectedSpecs();
          }

          // 解析商品描述
          final rawDescription = detailData['description']?.toString() ?? "暂无商品详情";
          String fixedDescription = rawDescription
              .replaceAll('src="//', 'src="https://')
              .replaceAll("src='//", "src='https://");
          _description = fixedDescription;
        }
      });

      // 加载评论
      if (_productId != null && _productId!.isNotEmpty) {
        _fetchProductComments();
      }
    } catch (e) {
      setState(() {
        _productTitle = "商品加载失败";
        _shopName = "未知店铺";
        _imageUrls = ["https://picsum.photos/id/237/400/400"];
        _description = AppLocalizations.of(context)?.translate('detail_load_fail') ?? "详情加载失败，请重试";
        _mainOriginalPriceKRW = 0.0;
        _mainPromotionPriceKRW = null;
        _mainOriginalPriceCNY = 0.0;
        _mainPromotionPriceCNY = null;
        _originalPriceKRW = 0.0;
        _promotionPriceKRW = null;
        _originalPriceCNY = 0.0;
        _promotionPriceCNY = null;
        _skuFeatureTexts.clear();
        _isCommentsLoading = false;
      });
    }
  }

  void _fetchProductComments() async {
    if (_productId == null || _productId!.isEmpty) {
      setState(() {
        _isCommentsLoading = false;
        _commentError = AppLocalizations.of(context)?.translate('product_id_empty') ?? "商品ID为空";
      });
      return;
    }

    try {
      final url = "${listByProductLimit}${_productId}";
      final response = await HttpUtil.get(url);

      if (response.data['code'] == 200) {
        List<dynamic> commentList = response.data['data'] as List? ?? [];
        setState(() {
          _realComments = commentList.map((json) => ProductComment.fromJson(json)).toList();
          _isCommentsLoading = false;
          _commentError = null;
        });
      } else {
        setState(() {
          _realComments = [];
          _isCommentsLoading = false;
          _commentError = AppLocalizations.of(context)?.translate('comment_load_fail') ?? "评论加载失败";
        });
      }
    } catch (e) {
      debugPrint("评论接口失败：$e");
      setState(() {
        _realComments = [];
        _isCommentsLoading = false;
        _commentError = AppLocalizations.of(context)?.translate('comment_load_fail') ?? "评论加载失败";
      });
    }
  }

  // 加入购物车接口调用方法
  Future<bool> _addToCart(dynamic selectedSku, {int quantity = 1}) async {
    // 校验关键参数
    if ((_productId == null || _productId!.isEmpty) || (_mpId == null || _mpId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('product_info_missing') ?? '商品信息缺失，无法加入购物车'
          )
        )
      );
      return false;
    }
    // 移除对selectedSku的强制校验，允许没有规格的商品也能添加到购物车

    try {
      // 登录校验（获取Token）
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('please_login') ?? '请先登录'
            )
          )
        );
        return false;
      }

      // 生成规格名称字符串
      String specName = "";
      
      // 优先从selectedSku的properties构建规格名称
      if (selectedSku != null && selectedSku['properties'] != null) {
        String lang = _getLangKey();
        List<dynamic> properties = selectedSku['properties'] as List? ?? [];
        
        if (properties.isNotEmpty) {
          List<String> specParts = [];
          for (var prop in properties) {
            String propName = prop["${lang}Name"] ?? '';
            String valueName = prop["${lang}Value"] ?? '';
            if (propName.isNotEmpty && valueName.isNotEmpty) {
              specParts.add('$propName:$valueName');
            }
          }
          if (specParts.isNotEmpty) {
            specName = specParts.join(',');
          }
        }
      }
      
      // 如果从properties构建失败，尝试使用selectedSku的secName
      if (specName.isEmpty && selectedSku != null && selectedSku['secName'] != null) {
        specName = selectedSku['secName'];
      }
      
      // 组装购物车参数
      final addCartParams = {
        "productId": _productId,
        "secId": selectedSku != null ? (selectedSku['sku_id'] ?? "0") : "0",
        "productName": _krTitle ?? _productTitle ?? "",
        "shopId": _shopId ?? 0,
        "shopName": _shopName ?? "",
        "secName": specName,  // 使用生成的规格名称字符串，如果为空则不传具体值
        "wangwangUrl": _wangwangUrl ?? "",
        "productUrl": _imageUrls.isNotEmpty ? _imageUrls[0] : "",
        "totalPrice": selectedSku != null ? ((selectedSku['price'] as num? ?? 0).toDouble() / 100.0) : _originalPriceCNY,
        "totalPlusPrice": selectedSku != null ? ((selectedSku['promotion_price'] as num? ?? (selectedSku['price'] as num? ?? 0)).toDouble() / 100.0) : (_promotionPriceCNY ?? _originalPriceCNY),
        "num": quantity,
        "productPrice": selectedSku != null ? ((selectedSku['price'] as num? ?? 0).toDouble() / 100.0) : _originalPriceCNY,
        "productPlusPrice": selectedSku != null ? ((selectedSku['promotion_price'] as num? ?? (selectedSku['price'] as num? ?? 0)).toDouble() / 100.0) : (_promotionPriceCNY ?? _originalPriceCNY),
        "minNum": _minNum,
        "sec": jsonEncode({
          "mpId": _mpId,
          "spmpId": (selectedSku != null ? selectedSku['mp_skuId']?.toString() : (_productDetailData?['data']?['data']?['skList'] is List && (_productDetailData?['data']?['data']?['skList'] as List).isNotEmpty ? (_productDetailData?['data']?['data']?['skList'] as List)[0]['mp_skuId']?.toString() : null)),
          "properties": selectedSku != null ? (selectedSku['properties'] ?? []) : []
        }),
        "wangwangTalkUrl": _wangwangTalkUrl ?? "",
        "productNameCn": _cnTitle ?? _productTitle ?? "",
        "productNameEn": _enTitle ?? _productTitle ?? "",
        "selfSupport": 1
      };

      // 发起POST请求
      final response = await HttpUtil.post(
        productcart,
        data: addCartParams,
      );

      if (response.data['code'] == 200) {
        return true;
      } else {
        throw Exception(response.data['msg'] ?? '加入购物车失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)?.translate('operation_failed') ?? '操作失败：'}${e.toString().replaceAll('Exception: ', '')}'
          )
        )
      );
      return false;
    }
  }

  void _showBottomSheet({bool isBuyNow = false}) {
    Map<String, String> _localSelectedSpecs = {};
    dynamic _localSelectedSku;
    int _quantity = 1; // 默认数量为1

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          if (_localSelectedSpecs.isEmpty) {
            if (_specGroups.isNotEmpty) {
              // 多规格商品
              _localSelectedSpecs = Map.from(_selectedSpecs);
              _localSelectedSku = _selectedSku;
            } else if (_skuList.isNotEmpty) {
              // 单规格商品，直接使用第一个SKU
              _localSelectedSku = _skuList.first;
            }
          }

          void _matchLocalSku() {
            if (_skuList.isEmpty || _localSelectedSpecs.isEmpty) return;

            String lang = _getLangKey();
            for (var sku in _skuList) {
              List<dynamic> properties = sku['properties'] ?? [];
              bool isMatch = true;

              for (var entry in _localSelectedSpecs.entries) {
                String targetPropName = entry.key;
                String targetValueName = entry.value;
                bool propMatch = false;

                for (var prop in properties) {
                  String propName = prop["${lang}Name"] ?? '';
                  String valueName = prop["${lang}Value"] ?? '';

                  if (propName == targetPropName && valueName == targetValueName) {
                    propMatch = true;
                    break;
                  }
                }

                if (!propMatch) {
                  isMatch = false;
                  break;
                }
              }

              if (isMatch) {
                sheetSetState(() {
                  _localSelectedSku = sku;
                  _quantity = 1; // 选择不同规格时重置数量为默认值
                });
                break;
              }
            }
          }

          // 价格单位转换：分 -> 元，并使用实时汇率
          double displayPriceCNY = _localSelectedSku != null
              ? ((_localSelectedSku['price'] as num? ?? 0).toDouble() / 100.0)
              : _mainOriginalPriceCNY;
          double? displayPromotionPriceCNY = _localSelectedSku != null
              ? _localSelectedSku['promotion_price'] != null
                  ? ((_localSelectedSku['promotion_price'] as num).toDouble() / 100.0)
                  : null
              : _mainPromotionPriceCNY;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      _imageUrls.isNotEmpty ? _imageUrls[0] : "https://picsum.photos/id/237/100/100",
                      width: 100.w,
                      height: 100.h,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(
                                  displayPromotionPriceCNY != null && displayPromotionPriceCNY != displayPriceCNY
                                    ? "¥${displayPromotionPriceCNY.toStringAsFixed(2)}"
                                    : "¥${displayPriceCNY.toStringAsFixed(2)}",
                                  style:  TextStyle(
                                    color: Colors.black,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (displayPromotionPriceCNY != null && displayPromotionPriceCNY != displayPriceCNY) ...[
                                SizedBox(width: 16.w),
                                Flexible(
                                  child: Text(
                                    "¥${displayPriceCNY.toStringAsFixed(2)}",
                                    style:  TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16.sp,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _productTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.sp),
                          ),
                          if (_localSelectedSku != null) ...[
                            SizedBox(height: 4.h),
                            Text(
                              "${AppLocalizations.of(context)?.translate('stock') ?? '库存'}: ${_localSelectedSku['quantity'] ?? 0}件",
                              style:  TextStyle(
                                color: Colors.grey,
                                fontSize: 12.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Text(
                                  "${AppLocalizations.of(context)?.translate('quantity') ?? '数量'}: ",
                                  style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                                ),
                                // 减号按钮
                                GestureDetector(
                                  onTap: () {
                                    if (_quantity > 1) {
                                      sheetSetState(() => _quantity--);
                                    }
                                  },
                                  child: Container(
                                    width: 24.w,
                                    height: 24.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey, width: 1.w),
                                      borderRadius: BorderRadius.circular(3.r),
                                    ),
                                    child: Text(
                                      '-',
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                // 数量显示
                                Container(
                                  width: 40.w,
                                  height: 24.h,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey, width: 1.w),
                                      bottom: BorderSide(color: Colors.grey, width: 1.w),
                                    ),
                                  ),
                                  child: Text(
                                    '$_quantity',
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                ),
                                // 加号按钮
                                GestureDetector(
                                  onTap: () {
                                    int maxQuantity = _localSelectedSku != null ? (_localSelectedSku['quantity'] ?? 1) : 1;
                                    if (_quantity < maxQuantity) {
                                      sheetSetState(() => _quantity++);
                                    }
                                  },
                                  child: Container(
                                    width: 24.w,
                                    height: 24.h,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey, width: 1.w),
                                      borderRadius: BorderRadius.circular(3.r),
                                    ),
                                    child: Text(
                                      '+',
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(height: 24.h),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_specGroups.isNotEmpty) ...[
                          ..._specGroups.entries.map((entry) {
                            String propName = entry.key;
                            List<String> values = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  propName,
                                  style:  TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    int maxButtonsPerRow = 3;
                                    if (constraints.maxWidth > 400) maxButtonsPerRow = 4;
                                    else if (constraints.maxWidth < 320) maxButtonsPerRow = 2;

                                    double buttonWidth = (constraints.maxWidth - (maxButtonsPerRow - 1) * 12) / maxButtonsPerRow;

                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        alignment: WrapAlignment.start,
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: values.map((value) {
                                          bool isSelected = _localSelectedSpecs[propName] == value;
                                          return SizedBox(
                                            width: buttonWidth,
                                            child: GestureDetector(
                                              onTap: () {
                                                sheetSetState(() => _localSelectedSpecs[propName] = value);
                                                _matchLocalSku();
                                              },
                                              behavior: HitTestBehavior.opaque,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: isSelected ? Colors.red : Colors.grey,
                                                    width: 1.w,
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  value,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.red : Colors.black,
                                                    fontSize: 14.sp,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 20.h),
                              ],
                            );
                          }).toList(),
                        ] else ...[
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            child: Text(
                              AppLocalizations.of(context)?.translate('no_spec_data') ?? "暂无规格数据",
                              style: TextStyle(fontSize: 14.sp),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPressed: () async {
                      if (!isBuyNow) {
                        // 加入购物车逻辑
                        bool addSuccess = await _addToCart(_localSelectedSku, quantity: _quantity);
                        if (addSuccess) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)?.translate('add_cart_success') ?? '加入购物车成功'
                              )
                            )
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => Cart())
                          );
                          // 更新页面选中状态
                          setState(() {
                            _selectedSpecs = _localSelectedSpecs;
                            _selectedSku = _localSelectedSku;
                            // 价格单位转换：分 -> 元
                            _originalPriceCNY = _localSelectedSku != null
                                ? ((_localSelectedSku['price'] as num? ?? 0).toDouble() / 100.0)
                                : _mainOriginalPriceCNY;
                            _promotionPriceCNY = _localSelectedSku != null
                                ? _localSelectedSku['promotion_price'] != null
                                    ? ((_localSelectedSku['promotion_price'] as num).toDouble() / 100.0)
                                    : null
                                : _mainPromotionPriceCNY;
                            
                            // 只有当汇率不为null时才计算韩元价格
                            _originalPriceKRW = _exchangeRate != null ? _originalPriceCNY * _exchangeRate! : 0.0;
                            _promotionPriceKRW = _promotionPriceCNY != null && _exchangeRate != null
                                ? _promotionPriceCNY! * _exchangeRate!
                                : null;
                          });
                        }
                      } else {
                        // 直接购买逻辑
                        Navigator.pop(context);
                        setState(() {
                          _selectedSpecs = _localSelectedSpecs;
                          _selectedSku = _localSelectedSku;
                          _originalPriceKRW = _localSelectedSku != null
                              ? (_localSelectedSku['price'] as num? ?? 0).toDouble()
                              : _mainOriginalPriceKRW;
                          _promotionPriceKRW = _localSelectedSku != null
                              ? (_localSelectedSku['promotion_price'] as num? ?? 0).toDouble()
                              : _mainPromotionPriceKRW;
                          _originalPriceCNY = displayPriceCNY;
                          _promotionPriceCNY = displayPromotionPriceCNY;
                        });
                      }
                    },
                    child: Text(
                      isBuyNow ? AppLocalizations.of(context)?.translate('buy_now_btn') ?? "直接购买" : AppLocalizations.of(context)?.translate('add_to_cart_btn') ?? "加入购物车",
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarRating(String starCount) {
    int stars = int.tryParse(starCount) ?? 0;
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: Colors.yellow,
          size: 16.r,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 商品图片轮播
                Stack(
                  children: [
                    _imageUrls.isEmpty
                        ? Container(
                            width: double.infinity,
                            height: 400.h,
                            color: Colors.grey[100],
                            child: const Center(child: CircularProgressIndicator()),
                          )
                        : SizedBox(
                            height: 400.h,
                            child: PageView.builder(
                              itemCount: _imageUrls.length,
                              onPageChanged: (index) => setState(() => _currentImageIndex = index),
                              itemBuilder: (context, index) => Image.network(
                                _imageUrls[index],
                                width: double.infinity,
                                height: 400.h,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child:  Icon(Icons.image_not_supported, size: 50.r, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                    if (_imageUrls.length > 1)
                      Positioned(
                        bottom: 16.h,
                        left: 0,
                        right: 0,
                        child: Container(
                          alignment: Alignment.center,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${_imageUrls.length}',
                              style: TextStyle(color: Colors.white, fontSize: 14.sp),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 16.h,
                      left: 16.w,
                      child: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white, size: 20.r),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16.h,
                      right: 16.w,
                      child: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.share, color: Colors.white, size: 20.r),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                // 平台信息栏
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                  color: const Color(0xFFF5F5F5),
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)?.translate('taobao') ?? "淘宝网",
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                      Text(AppLocalizations.of(context)?.translate('view_on') ?? "上查看", style: const TextStyle(color: Colors.grey)),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.translate('seller_product_view') ?? "查看卖家·商品",
                          style: TextStyle(color: Colors.white, fontSize: 12.sp),
                        ),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: currentLanguage,
                        items: const [
                          DropdownMenuItem(value: "中文", child: Text("中文")),
                          DropdownMenuItem(value: "English", child: Text("English")),
                          DropdownMenuItem(value: "한국어", child: Text("한국어")),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              currentLanguage = value;
                              _productTitle = _getCurrentTitle();
                              _generateSpecsByLanguage();
                              _initSelectedSpecs();
                            });
                          }
                        },
                        underline: const SizedBox(),
                        style: TextStyle(fontSize: 14.sp, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                // 规格特征文本
                // if (_skuFeatureTexts.isNotEmpty)
                //   Container(
                //     padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                //     color: Colors.white,
                //     child: SingleChildScrollView(
                //       scrollDirection: Axis.horizontal,
                //       child: Row(
                //         children: _skuFeatureTexts
                //             .map((text) => Container(
                //                   margin: EdgeInsets.only(right: 20.w),
                //                   padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                //                   decoration: BoxDecoration(
                //                     border: Border.all(color: Colors.grey.shade300, width: 1.w),
                //                     borderRadius: BorderRadius.circular(4.r),
                //                   ),
                //                   child: Text(text, style: TextStyle(fontSize: 14.sp)),
                //                 ))
                //             .toList(),
                //       ),
                //     ),
                //   ),
                // SizedBox(height: 8.h),
                // 商品标题
                Container(
                  padding: EdgeInsets.all(16.w),
                  color: Colors.white,
                  child: Text(
                    _productTitle,
                    style: TextStyle(fontSize: 16.sp, height: 1.3),
                  ),
                ),
                SizedBox(height: 8.h),
                // 价格展示
                Container(
                  padding: EdgeInsets.all(16.w),
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _mainPromotionPriceKRW != null && _mainPromotionPriceKRW != _mainOriginalPriceKRW
                            ? "KRW ${((_mainPromotionPriceKRW! / 10).floor() * 10).toString()}"
                            : "KRW ${((_mainOriginalPriceKRW / 10).floor() * 10).toString()}",
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_mainPromotionPriceKRW != null && _mainPromotionPriceKRW != _mainOriginalPriceKRW) ...[
                        SizedBox(width: 8.w),
                        Text(
                          "KRW ${((_mainOriginalPriceKRW / 10).floor() * 10).toString()}",
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      SizedBox(width: 16.w),
                      Text(
                        _mainPromotionPriceCNY != null && _mainPromotionPriceCNY != _mainOriginalPriceCNY
                            ? "¥${_mainPromotionPriceCNY?.toStringAsFixed(2)}"
                            : "¥${_mainOriginalPriceCNY.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                // 评价区域
                Container(
                  padding: EdgeInsets.all(16.w),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 评价标题区域
                      InkWell(
                        onTap: () {
                          if (_productId == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ShopReviewsPage(itemId: _productId!)),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Text(
                            AppLocalizations.of(context)?.translate('Reviews') ?? "评价",
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // 评论列表
                      _isCommentsLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _commentError != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Text(_commentError!),
                                  ),
                                )
                              : _realComments.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 20),
                                        child: Text(AppLocalizations.of(context)?.translate('no_comments') ?? "暂无评论"),
                                      ),
                                    )
                                  : Column(
                                      children: _realComments
                                          .map((comment) => Container(
                                                margin: EdgeInsets.only(bottom: 16.h),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // 评论头像添加点击跳转
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (comment.memberId == 0) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                AppLocalizations.of(context)?.translate('user_id_missing') ?? "用户ID缺失，无法跳转"
                                                              )
                                                            ),
                                                          );
                                                          return;
                                                        }
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => userCommentsPage(
                                                              memberId: comment.memberId.toString(),
                                                              nickname: comment.nickname,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      behavior: HitTestBehavior.translucent,
                                                      child: ClipOval(
                                                        child: comment.memberAvator != null
                                                            ? Image.network(
                                                                _fixImageUrl(comment.memberAvator!),
                                                                width: 18.w,
                                                                height: 18.h,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (_, __, ___) =>
                                                                    Icon(Icons.person, size: 18.r, color: Colors.grey),
                                                              )
                                                            : Icon(Icons.person, size: 18.r, color: Colors.grey),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              // 显示 nickname
                                                              Text(
                                                                comment.nickname,
                                                                style: TextStyle(fontSize: 14.sp),
                                                              ),
                                                              // VIP标识
                                                              if (comment.goodObserve == "2") ...[
                                                                SizedBox(width: 4.w),
                                                                Container(
                                                                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                                                                  color: Colors.orange,
                                                                  child: Text(
                                                                    "V",
                                                                    style: TextStyle(color: Colors.white, fontSize: 10.sp),
                                                                  ),
                                                                ),
                                                              ],
                                                              SizedBox(width: 8.w),
                                                              Text(
                                                                comment.parsedSec,
                                                                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                                                              ),
                                                            ],
                                                          ),
                                                          SizedBox(height: 8.h),
                                                          _buildStarRating(comment.star),
                                                          SizedBox(height: 4.h),
                                                          Text(
                                                            comment.info,
                                                            style: TextStyle(fontSize: 14.sp),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    // 评论图片
                                                    if (comment.pictureUrl != null && comment.pictureUrl!.isNotEmpty)
                                                      Image.network(
                                                        _fixImageUrl(comment.pictureUrl!),
                                                        width: 100.w,
                                                        height: 100.h,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Icon(Icons.error, color: Colors.red, size: 20.r),
                                                      ),
                                                  ],
                                                ),
                                              ))
                                          .toList(),
                                    ),
                      SizedBox(height: 20.h),
                      // 店铺信息
                      Row(
                        children: [
                          ClipOval(
                            child: Image.network(
                              "https://picsum.photos/id/64/60/60",
                              width: 50.w,
                              height: 50.h,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _shopName,
                                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 4.h),
                              ],
                            ),
                          ),
                          Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 24.r),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${AppLocalizations.of(context)?.translate('product_quality') ?? '宝贝质量'}5.0",
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                AppLocalizations.of(context)?.translate('100vip_positive_rate') ?? "100VIP 好评率100%",
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                "${AppLocalizations.of(context)?.translate('service_guarantee') ?? '服务保障'}5.0",
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                AppLocalizations.of(context)?.translate('100vip_positive_rate') ?? "100VIP 好评率100%",
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      // 商品详情
                      Text(
                        AppLocalizations.of(context)?.translate('ProductDetails') ?? "宝贝详情",
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 12.h),
                      _description.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                child: const CircularProgressIndicator(),
                              ),
                            )
                          : Html(
                              data: _description,
                              style: {
                                "*": Style(
                                  width: Width(MediaQuery.of(context).size.width - 32),
                                ),
                              },
                            ),
                    ],
                  ),
                ),
                SizedBox(height: 80.h),
              ],
            ),
          ),
          // 底部操作栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.favorite,
                    size: 28.r,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleFavorite,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: () => _showBottomSheet(isBuyNow: false),
                      child: Text(
                        AppLocalizations.of(context)?.translate('add_to_cart_kr') ?? "加入购物车",
                        style: TextStyle(fontSize: 16.sp, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onPressed: () => _showBottomSheet(isBuyNow: true),
                      child: Text(
                        AppLocalizations.of(context)?.translate('buy_request_kr') ?? "请求购买",
                        style: TextStyle(fontSize: 16.sp, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}