import 'package:flutter/material.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'package:flutter_mall/utils/http_util.dart';
import './config/service_url.dart';
import './dingbudaohang.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:developer' as debug;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'review.dart';
import 'userreviews.dart';
import 'package:video_player/video_player.dart';

class SelfProductDetails extends StatefulWidget {
  final String id; // 商品ID

  const SelfProductDetails({super.key, required this.id});

  @override
  State<SelfProductDetails> createState() => _SelfProductDetailsState();
}

class _SelfProductDetailsState extends State<SelfProductDetails> {
  dynamic _productDetailData;
  List<dynamic> _images = [];
  List<dynamic> _productSkuNameList = []; // 规格名称列表
  List<dynamic> _productSkuDetailList = []; // 规格详细信息列表
  Map<String, dynamic> _selectedSku = {}; // 选中的规格
  Map<String, String> _selectedSpecs = {}; // 选中的规格名称-值对
  bool isFavorite = false;
  bool _isLoading = true;
  String _mpId = '';
  double _exchangeRate = 0;
  String _currentLanguage = '中文';
  String _currentPrice = '0.00';
  String _currentPricePlus = '0.00';
  bool _isPlus = false; // 是否会员商品
  String _productTitle = ''; // 商品标题
  double _originalPriceCNY = 0.0; // 原价（人民币）
  double? _promotionPriceCNY; // 促销价（人民币）
  int _minNum = 1; // 最小起购数量
  List<String> _skuFeatureTexts = []; // SKU特性文本

  // 评论数据
  List<dynamic> _realComments = [];
  bool _isCommentsLoading = true;
  String? _commentError;

  // 商品ID（用于评论接口）
  String? _productId;

  // 当前图片页码
  int _currentPage = 0;

  // 视频相关
  String? _videoUrl; // 视频URL
  bool _hasVideo = false; // 是否有视频

  @override
  void initState() {
    super.initState();
    _fetchExchangeRate();
    _fetchProductDetail();
  }

  // 获取汇率
  void _fetchExchangeRate() async {
    try {
      final response = await HttpUtil.get(
        searchRateUrl,
        queryParameters: {
          'currency': 2, // 根据search.dart中的修改，这里应该是2表示韩元
          'type': 1,
          'benchmarkCurrency': 1, // 1表示人民币
        },
      );
      if (response.data != null && response.data['code'] == 200) {
        setState(() {
          // 服务器直接返回汇率值在data字段中
          _exchangeRate = double.parse(response.data['data'].toString());
        });
      }
    } catch (e) {
      print('获取汇率失败: $e');
    }
  }

  // 修复图片URL，确保有正确的协议前缀
  String _fixImageUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    
    return 'https://$url';
  }

  // 获取商品详情
  void _fetchProductDetail() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final initialProductId = widget.id;
      final response = await HttpUtil.get(
        selfProductDetailUrl + initialProductId,
      );

      setState(() {
        _productDetailData = response.data;
        if (_productDetailData != null && _productDetailData['code'] == 200) {
          final data = _productDetailData['data'];
          final productAutom = data['productAutom'];

          // 处理商品图片
          if (productAutom['picture'] != null &&
              productAutom['picture'].isNotEmpty) {
            _images =
                productAutom['picture']
                    .split(',')
                    .map((url) => _fixImageUrl(url))
                    .toList();
          }

          // 处理商品视频
          if (productAutom['video'] != null &&
              productAutom['video'].isNotEmpty) {
            _videoUrl = productAutom['video'];
            _hasVideo = true;
          } else {
            _hasVideo = false;
          }

          // 处理规格数据
          List<dynamic> rawSkuNameList = data['productSkuNameList'] ?? [];
          // 彻底去重规格名称，确保每个规格只显示一次
          Map<String, dynamic> uniqueSkuNames = {};
          for (var skuName in rawSkuNameList) {
            String skuNameStr = skuName['skuName'] ?? '';
            if (skuNameStr.isNotEmpty &&
                !uniqueSkuNames.containsKey(skuNameStr)) {
              uniqueSkuNames[skuNameStr] = skuName;
            }
          }
          _productSkuNameList = uniqueSkuNames.values.toList();
          _productSkuDetailList = data['productSkuDetailList'] ?? [];

          // 设置默认选中的规格
          if (_productSkuDetailList.isNotEmpty) {
            _selectedSku = _productSkuDetailList[0];
            // 初始化选中的规格名称-值对
            if (_selectedSku['productSkuNameDTOList'] != null) {
              for (var skuNameDto in _selectedSku['productSkuNameDTOList']) {
                if (skuNameDto['skuName'] != null &&
                    skuNameDto['productSkus'] != null) {
                  _selectedSpecs[skuNameDto['skuName']] = 
                      skuNameDto['productSkus']['secValue'];
                }
              }
            }
          }
          
          // 生成SKU特性文本 - 获取第一个规格属性下的所有可能值
          List<String> newFeatureTexts = [];
          if (_productSkuNameList.isNotEmpty && _productSkuDetailList.isNotEmpty) {
            // 获取第一个规格属性的名称
            String firstSpecName = _productSkuNameList[0]['skuName'] ?? '';
            if (firstSpecName.isNotEmpty) {
              // 收集该规格属性下的所有可能值
              Set<String> values = {};
              for (var skuDetail in _productSkuDetailList) {
                if (skuDetail['productSkuNameDTOList'] != null) {
                  for (var skuNameDto in skuDetail['productSkuNameDTOList']) {
                    if (skuNameDto['skuName'] == firstSpecName && skuNameDto['productSkus'] != null) {
                      values.add(skuNameDto['productSkus']['secValue']);
                    }
                  }
                }
              }
              // 转换为列表
              newFeatureTexts = values.toList();
            }
          }
          _skuFeatureTexts = newFeatureTexts;

          // 设置商品标题
          _productTitle = _getProductName(productAutom);

          // 设置价格
          _currentPrice = productAutom['price'] ?? '0.00';
          _currentPricePlus = productAutom['pricePlus'] ?? '0.00';
          _isPlus = productAutom['plus'] == '2'; // 2=是会员商品

          // 设置人民币价格
          _originalPriceCNY = double.tryParse(_currentPrice) ?? 0.0;
          if (_isPlus && double.tryParse(_currentPricePlus) != null) {
            _promotionPriceCNY = double.tryParse(_currentPricePlus) ?? 0.0;
          }

          // 设置最小起购数量
          _minNum =
              int.tryParse(productAutom['minPayNum']?.toString() ?? '1') ?? 1;

          // 设置商品ID（用于评论接口）
          _productId = initialProductId;

          _isLoading = false;

          // 获取商品评论
          _fetchProductComments();
        }
      });
    } catch (e) {
      print('获取商品详情失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 格式化SKU列表为JSON字符串
  String _getSkuListJson() {
    try {
      return jsonEncode(_productSkuDetailList);
    } catch (e) {
      debug.log("SKU列表JSON序列化失败: $e");
      return "[]";
    }
  }

  // 获取商品评论
  void _fetchProductComments() async {
    if (_productId == null || _productId!.isEmpty) {
      setState(() {
        _isCommentsLoading = false;
        _commentError =
            AppLocalizations.of(context)?.translate('product_id_empty') ??
            "商品ID为空";
      });
      return;
    }

    try {
      // 注意：自营商品的评论接口可能与普通商品不同，这里暂时使用相同的接口
      final url = "${listByProductLimit}${_productId}";
      debug.log("自营商品评论接口URL：$url");
      final response = await HttpUtil.get(url);
      debug.log("自营商品评论接口返回：${response.data}");

      if (response.data['code'] == 200) {
        List<dynamic> commentList = response.data['data'] as List? ?? [];
        setState(() {
          _realComments = commentList;
          _isCommentsLoading = false;
          _commentError = null;
        });
      } else {
        setState(() {
          _realComments = [];
          _isCommentsLoading = false;
          _commentError =
              AppLocalizations.of(context)?.translate('comment_load_fail') ??
              "评论加载失败";
        });
      }
    } catch (e) {
      debug.log("自营商品评论接口失败：$e");
      setState(() {
        _realComments = [];
        _isCommentsLoading = false;
        _commentError =
            AppLocalizations.of(context)?.translate('comment_load_fail') ??
            "评论加载失败";
      });
    }
  }

  // 获取商品名称（根据当前语言）
  String _getProductName(dynamic productData) {
    if (productData == null) return '';

    switch (_currentLanguage) {
      case 'zh':
        return productData['productNameCn'] ?? productData['productName'] ?? '';
      case 'en':
        return productData['productNameEn'] ?? productData['productName'] ?? '';
      default:
        return productData['productName'] ?? '';
    }
  }

  // 获取规格名称（根据当前语言）
  String _getSkuName(dynamic skuNameData) {
    if (skuNameData == null) return '';

    switch (_currentLanguage) {
      case 'zh':
        return skuNameData['skuNameCn'] ?? skuNameData['skuName'] ?? '';
      case 'en':
        return skuNameData['skuNameEn'] ?? skuNameData['skuName'] ?? '';
      default:
        return skuNameData['skuName'] ?? '';
    }
  }

  // 获取规格值（根据当前语言）
  String _getSkuValue(dynamic skuValueData) {
    if (skuValueData == null) return '';

    switch (_currentLanguage) {
      case 'zh':
        return skuValueData['secValueCn'] ?? skuValueData['secValue'] ?? '';
      case 'en':
        return skuValueData['secValueEn'] ?? skuValueData['secValue'] ?? '';
      default:
        return skuValueData['secValue'] ?? '';
    }
  }

  // 处理规格选择
  void _selectSku(Map<String, dynamic> sku) {
    setState(() {
      _selectedSku = sku;
      // 更新价格
      if (sku['productSkuDetail'] != null) {
        _currentPrice = sku['productSkuDetail']['price']?.toString() ?? '0.00';
        _currentPricePlus =
            sku['productSkuDetail']['pricePlus']?.toString() ?? '0.00';
      }
    });
  }

  // 添加到购物车
  Future<bool> _addToCart([
    Map<String, dynamic>? selectedSku,
    Map<String, String>? selectedSpecs,
  ]) async {
    // 校验关键参数
    if ((_productId == null || _productId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.translate('product_info_missing') ??
                '商品信息缺失，无法加入购物车',
          ),
        ),
      );
      return false;
    }

    try {
      // 登录校验（获取Token）
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('please_login') ?? '请先登录',
            ),
          ),
        );
        return false;
      }

      final targetSku = selectedSku ?? _selectedSku;
      final targetSpecs = selectedSpecs ?? _selectedSpecs;

      // 生成规格名称字符串
      String specName = "";
      if (targetSku.isNotEmpty && targetSku['productSkuNameDTOList'] != null) {
        // 使用用户选择的规格生成specName，避免重复
        List<String> specParts = [];
        for (var entry in targetSpecs.entries) {
          String propName = entry.key;
          String valueName = entry.value;
          if (propName.isNotEmpty && valueName.isNotEmpty) {
            specParts.add('$propName:$valueName');
          }
        }
        if (specParts.isNotEmpty) {
          specName = specParts.join(',');
        }
      }

      // 获取当前选择规格的价格
      double currentPrice =
          targetSku.isNotEmpty && targetSku['productSkuDetail'] != null
              ? double.tryParse(
                    targetSku['productSkuDetail']['price']?.toString() ??
                        '0.00',
                  ) ??
                  0.00
              : _originalPriceCNY;

      double currentPromotionPrice =
          _isPlus &&
                  targetSku.isNotEmpty &&
                  targetSku['productSkuDetail'] != null
              ? double.tryParse(
                    targetSku['productSkuDetail']['pricePlus']?.toString() ??
                        '0.00',
                  ) ??
                  0.00
              : (_promotionPriceCNY ?? currentPrice);

      // 组装购物车参数
      final addCartParams = {
        "productId": _productId,
        "secId":
            targetSku.isNotEmpty
                ? (targetSku['productSkuDetail']?['skuDetailId'] ?? "0")
                : "0",
        "productName": _productTitle,
        "shopId": 0, // 自营商品店铺ID可能为0
        "shopName": "自营店铺",
        "secName": specName, // 使用生成的规格名称字符串，如果为空则不传具体值
        "wangwangUrl": "",
        "productUrl": _images.isNotEmpty ? _images[0] : "",
        "totalPrice": currentPrice,
        "totalPlusPrice": currentPromotionPrice,
        "num": 1,
        "productPrice": currentPrice,
        "productPlusPrice": currentPromotionPrice,
        "minNum": _minNum,
        "sec": jsonEncode({
          "mpId": _mpId,
          "spmpId":
              targetSku.isNotEmpty &&
                      targetSku['productSkuDetail']?['skuDetailId'] != null
                  ? targetSku['productSkuDetail']['skuDetailId'].toString()
                  : "0",
          "properties":
              targetSpecs.entries.map((entry) {
                String skuName = entry.key;
                String secValue = entry.value;
                return {
                  "cnName": skuName,
                  "enName": skuName,
                  "krName": skuName,
                  "cnValue": secValue,
                  "enValue": secValue,
                  "krValue": secValue,
                };
              }).toList(),
        }),
        "wangwangTalkUrl": "",
        "productNameCn": _productTitle,
        "productNameEn": _productTitle,
        "selfSupport": 2, // 2表示自营商品
      };

      // 发起POST请求
      final response = await HttpUtil.post(productcart, data: addCartParams);

      if (response.data['code'] == 200) {
        return true;
      } else {
        throw Exception(response.data['msg'] ?? '加入购物车失败');
      }
    } catch (e) {
      print('添加到购物车失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)?.translate('operation_failed') ?? '操作失败：'}${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
      return false;
    }
  }

  // 显示底部弹窗
  void _showBottomSheet({bool isBuyNow = false}) {
    Map<String, String> _localSelectedSpecs = {};
    Map<String, dynamic> _localSelectedSku = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder: (sheetContext, sheetSetState) {
              if (_localSelectedSpecs.isEmpty && _selectedSpecs.isNotEmpty) {
                _localSelectedSpecs = Map.from(_selectedSpecs);
                _localSelectedSku = _selectedSku;
              }

              // 匹配选中的规格对应的SKU
              void _matchLocalSku() {
                if (_productSkuDetailList.isEmpty ||
                    _localSelectedSpecs.isEmpty)
                  return;

                for (var sku in _productSkuDetailList) {
                  if (sku['productSkuNameDTOList'] == null) continue;
                  bool isMatch = true;

                  for (var entry in _localSelectedSpecs.entries) {
                    String targetPropName = entry.key;
                    String targetValueName = entry.value;
                    bool propMatch = false;

                    for (var skuNameDto in sku['productSkuNameDTOList']) {
                      if (skuNameDto['skuName'] == targetPropName &&
                          skuNameDto['productSkus'] != null &&
                          skuNameDto['productSkus']['secValue'] ==
                              targetValueName) {
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
                    sheetSetState(() => _localSelectedSku = sku);
                    break;
                  }
                }
              }

              // 价格显示
              double displayPriceCNY =
                  _localSelectedSku.isNotEmpty &&
                          _localSelectedSku['productSkuDetail'] != null
                      ? double.tryParse(
                            _localSelectedSku['productSkuDetail']['price']
                                    ?.toString() ??
                                '0.00',
                          ) ??
                          0.00
                      : _originalPriceCNY;
              double? displayPromotionPriceCNY;
              if (_isPlus &&
                  _localSelectedSku.isNotEmpty &&
                  _localSelectedSku['productSkuDetail'] != null) {
                double pricePlus =
                    double.tryParse(
                      _localSelectedSku['productSkuDetail']['pricePlus']
                              ?.toString() ??
                          '0.00',
                    ) ??
                    0.00;
                if (pricePlus > 0 && pricePlus < displayPriceCNY) {
                  displayPromotionPriceCNY = pricePlus;
                }
              } else if (_promotionPriceCNY != null &&
                  _promotionPriceCNY! < displayPriceCNY) {
                displayPromotionPriceCNY = _promotionPriceCNY;
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          _images.isNotEmpty
                              ? _images[0]
                              : "https://picsum.photos/id/237/100/100",
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.error, color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    displayPromotionPriceCNY != null &&
                                            displayPromotionPriceCNY !=
                                                displayPriceCNY
                                        ? "¥${displayPromotionPriceCNY.toStringAsFixed(2)}"
                                        : "¥${displayPriceCNY.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (displayPromotionPriceCNY != null &&
                                      displayPromotionPriceCNY !=
                                          displayPriceCNY) ...[
                                    const SizedBox(width: 16),
                                    Text(
                                      "¥${displayPriceCNY.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _productTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (_localSelectedSku.isNotEmpty &&
                                  _localSelectedSku['productSkuDetail'] !=
                                      null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "${AppLocalizations.of(context)?.translate('stock') ?? '库存'}: ${_localSelectedSku['productSkuDetail']['inventory'] ?? 0}件",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
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
                    const Divider(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_productSkuNameList.isNotEmpty) ...[
                              ..._productSkuNameList.map((skuName) {
                                String propName = skuName['skuName'] ?? '';

                                // 获取该规格名称下的所有可能值
                                Set<String> values = {};
                                for (var skuDetail in _productSkuDetailList) {
                                  if (skuDetail['productSkuNameDTOList'] !=
                                      null) {
                                    for (var skuNameDto
                                        in skuDetail['productSkuNameDTOList']) {
                                      if (skuNameDto['skuName'] == propName &&
                                          skuNameDto['productSkus'] != null) {
                                        values.add(
                                          skuNameDto['productSkus']['secValue'],
                                        );
                                      }
                                    }
                                  }
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      propName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        int maxButtonsPerRow = 3;
                                        if (constraints.maxWidth > 400)
                                          maxButtonsPerRow = 4;
                                        else if (constraints.maxWidth < 320)
                                          maxButtonsPerRow = 2;

                                        double buttonWidth =
                                            (constraints.maxWidth -
                                                (maxButtonsPerRow - 1) * 12) /
                                            maxButtonsPerRow;

                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Wrap(
                                            alignment: WrapAlignment.start,
                                            spacing: 12,
                                            runSpacing: 12,
                                            children:
                                                values.map((value) {
                                                  bool isSelected =
                                                      _localSelectedSpecs[propName] ==
                                                      value;
                                                  return SizedBox(
                                                    width: buttonWidth,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        sheetSetState(() {
                                                          _localSelectedSpecs[propName] =
                                                              value;
                                                          _matchLocalSku();
                                                        });
                                                      },
                                                      behavior:
                                                          HitTestBehavior
                                                              .opaque,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color:
                                                                isSelected
                                                                    ? Colors.red
                                                                    : Colors
                                                                        .grey,
                                                            width: 1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text(
                                                          value,
                                                          style: TextStyle(
                                                            color:
                                                                isSelected
                                                                    ? Colors.red
                                                                    : Colors
                                                                        .black,
                                                            fontSize: 14,
                                                          ),
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                );
                              }).toList(),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.translate('no_spec_data') ??
                                      "暂无规格数据",
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          if (!isBuyNow) {
                            // 加入购物车逻辑
                            bool addSuccess = await _addToCart(
                              _localSelectedSku,
                              _localSelectedSpecs,
                            );
                            if (addSuccess) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.translate('add_cart_success') ??
                                        '加入购物车成功',
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                              // 更新页面选中状态
                              setState(() {
                                _selectedSpecs = _localSelectedSpecs;
                                _selectedSku = _localSelectedSku;
                                // 更新价格
                                if (_localSelectedSku.isNotEmpty &&
                                    _localSelectedSku['productSkuDetail'] !=
                                        null) {
                                  _currentPrice =
                                      _localSelectedSku['productSkuDetail']['price']
                                          ?.toString() ??
                                      '0.00';
                                  _currentPricePlus =
                                      _localSelectedSku['productSkuDetail']['pricePlus']
                                          ?.toString() ??
                                      '0.00';
                                  _originalPriceCNY =
                                      double.tryParse(_currentPrice) ?? 0.0;
                                  if (_isPlus &&
                                      double.tryParse(_currentPricePlus) !=
                                          null) {
                                    _promotionPriceCNY =
                                        double.tryParse(_currentPricePlus) ??
                                        0.0;
                                  }
                                }
                              });
                            }
                          } else {
                            // 直接购买逻辑
                            Navigator.pop(context);
                            setState(() {
                              _selectedSpecs = _localSelectedSpecs;
                              _selectedSku = _localSelectedSku;
                              // 更新价格
                              if (_localSelectedSku.isNotEmpty &&
                                  _localSelectedSku['productSkuDetail'] !=
                                      null) {
                                _currentPrice =
                                    _localSelectedSku['productSkuDetail']['price']
                                        ?.toString() ??
                                    '0.00';
                                _currentPricePlus =
                                    _localSelectedSku['productSkuDetail']['pricePlus']
                                        ?.toString() ??
                                    '0.00';
                                _originalPriceCNY =
                                    double.tryParse(_currentPrice) ?? 0.0;
                                if (_isPlus &&
                                    double.tryParse(_currentPricePlus) !=
                                        null) {
                                  _promotionPriceCNY =
                                      double.tryParse(_currentPricePlus) ?? 0.0;
                                }
                              }
                            });
                          }
                        },
                        child: Text(
                          isBuyNow
                              ? AppLocalizations.of(
                                    context,
                                  )?.translate('buy_now') ??
                                  "立即购买"
                              : AppLocalizations.of(
                                    context,
                                  )?.translate('add_to_cart_btn') ??
                                  "加入购物车",
                          style: const TextStyle(
                            fontSize: 16,
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

  // 收藏商品
  void _toggleFavorite() async {
    if (_productId == null || _productId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
                  context,
                )?.translate('product_info_missing_operate') ??
                '商品信息缺失，操作失败',
          ),
        ),
      );
      return;
    }

    final bool wasFavorite = isFavorite;
    setState(() => isFavorite = !isFavorite);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('please_login') ?? '请先登录',
            ),
          ),
        );
        setState(() => isFavorite = wasFavorite);
        return;
      }

      if (!wasFavorite) {
        final collectParams = {
          "productId": int.tryParse(_productId!) ?? 0,
          "productName": _productTitle,
          "productNameCn": _productTitle,
          "productNameEn": _productTitle,
          "shopId": 0, // 自营商品店铺ID可能为0
          "shopName": "自营店铺",
          "wangwangUrl": "",
          "productUrl": _images.isNotEmpty ? _images[0] : "",
          "minNum": _minNum,
          "sec": _getSkuListJson(),
          "wangwangTalkUrl": "",
          "selfSupport": 2,
        };

        final response = await HttpUtil.post(getcollect, data: collectParams);

        if (response.data['code'] != 200 && !response.data['success']) {
          throw Exception(response.data['msg'] ?? '收藏失败');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('collect_success') ??
                  '收藏成功',
            ),
          ),
        );
      } else {
        String cancelUrl = reamcollect.replaceAll(
          RegExp(r'\{productId\}'),
          _productId!,
        );
        final response = await HttpUtil.del(cancelUrl);

        if (response.data['code'] != 200 && !response.data['success']) {
          throw Exception(response.data['msg'] ?? '取消收藏失败');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('cancel_collect_success') ??
                  '取消收藏成功',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => isFavorite = wasFavorite);
      debug.log('收藏操作异常：$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)?.translate('operation_failed') ?? '操作失败：'}${e.toString()}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildProductDetails(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // 构建商品详情页面
  Widget _buildProductDetails() {
    if (_productDetailData == null || _productDetailData['code'] != 200) {
      return Center(
        child: Text(AppLocalizations.of(context)!.translate('load_failed')),
      );
    }

    final data = _productDetailData['data'];
    final productAutom = data['productAutom'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品图片轮播
          _buildImageCarousel(),

          // 平台信息栏
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: const Color(0xFFF5F5F5),
            child: Row(
              children: [
                Text(
                  '自营商品',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '平台保障',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),

          // 商品基本信息
          _buildProductInfo(productAutom),

          // 商品价格
          _buildPriceSection(productAutom),

          // 评论部分
          _buildCommentsSection(),

          // 商品详情
          _buildProductDetailSection(productAutom),
        ],
      ),
    );
  }

  // 构建图片轮播
  Widget _buildImageCarousel() {
    // 组合图片和视频
    List<Widget> mediaList = [];

    // 如果有视频，先添加视频
    if (_hasVideo && _videoUrl != null) {
      mediaList.add(_buildVideoPlayer());
    }

    // 再添加所有图片
    for (int i = 0; i < _images.length; i++) {
      mediaList.add(
        Image.network(
          _images[i],
          fit: BoxFit.cover,
          width: double.infinity,
          height: 400,
          errorBuilder:
              (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
        ),
      );
    }

    if (mediaList.isEmpty) {
      return Container(
        width: double.infinity,
        height: 400,
        color: Colors.grey[200],
        child: const Center(child: Text('暂无媒体内容')),
      );
    }

    return SizedBox(
      height: 400,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: mediaList.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return mediaList[index];
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                onPressed: () {},
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          // 媒体页码指示器
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1}/${mediaList.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建视频播放器
  Widget _buildVideoPlayer() {
    if (_videoUrl == null) {
      return Container(
        color: Colors.black,
        child: const Center(child: Text('视频加载失败')),
      );
    }

    return VideoPlayerScreen(videoUrl: _videoUrl!);
  }

  // 构建商品基本信息
  Widget _buildProductInfo(Map<String, dynamic> productAutom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SKU特性文本区域 - 移到标题上面
        if (_skuFeatureTexts.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _skuFeatureTexts
                    .map((text) => Container(
                          margin: const EdgeInsets.only(right: 20),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(text, style: const TextStyle(fontSize: 14)),
                        ))
                    .toList(),
              ),
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getProductName(productAutom),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  // 构建价格部分
  Widget _buildPriceSection(Map<String, dynamic> productAutom) {
    // 计算韩元价格
    double mainOriginalPriceCNY = _originalPriceCNY;
    double? mainPromotionPriceCNY = _promotionPriceCNY;

    // 韩元价格
    double mainOriginalPriceKRW = mainOriginalPriceCNY * _exchangeRate;
    double? mainPromotionPriceKRW =
        mainPromotionPriceCNY != null
            ? mainPromotionPriceCNY * _exchangeRate
            : null;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mainPromotionPriceKRW != null &&
                    mainPromotionPriceKRW != mainOriginalPriceKRW
                ? "KRW ${mainPromotionPriceKRW.toStringAsFixed(0)}"
                : "KRW ${mainOriginalPriceKRW.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (mainPromotionPriceKRW != null &&
              mainPromotionPriceKRW != mainOriginalPriceKRW) ...[
            const SizedBox(height: 4),
            Text(
              "KRW ${mainOriginalPriceKRW.toStringAsFixed(0)}",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            mainPromotionPriceCNY != null &&
                    mainPromotionPriceCNY != mainOriginalPriceCNY
                ? "¥${mainPromotionPriceCNY.toStringAsFixed(2)}"
                : "¥${mainOriginalPriceCNY.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 构建商品详情部分
  Widget _buildProductDetailSection(Map<String, dynamic> productAutom) {
    final productDetail = productAutom['productDetail'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.translate('ProductDetails'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 解析并显示HTML商品详情
          productDetail.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
              : Html(
                data: productDetail,
                style: {
                  "*": Style(
                    width: Width(MediaQuery.of(context).size.width - 32),
                  ),
                },
              ),
        ],
      ),
    );
  }

  // 构建评论部分
  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 评价标题区域
          InkWell(
            onTap: () {
              if (_productId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopReviewsPage(itemId: _productId!),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppLocalizations.of(context)?.translate('Reviews') ?? "评价",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                  child: Text(
                    AppLocalizations.of(context)?.translate('no_comments') ??
                        "暂无评论",
                  ),
                ),
              )
              : Column(
                children:
                    _realComments
                        .map(
                          (comment) => Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 评论头像添加点击跳转
                                GestureDetector(
                                  onTap: () {
                                    if (comment['memberId'] == null ||
                                        comment['memberId'] == 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            AppLocalizations.of(
                                                  context,
                                                )?.translate(
                                                  'user_id_missing',
                                                ) ??
                                                "用户ID缺失，无法跳转",
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => userCommentsPage(
                                              memberId:
                                                  comment['memberId']
                                                      .toString(),
                                              nickname:
                                                  comment['nickname'] ?? "匿名用户",
                                            ),
                                      ),
                                    );
                                  },
                                  behavior: HitTestBehavior.translucent,
                                  child: ClipOval(
                                    child:
                                        comment['memberAvator'] != null
                                            ? Image.network(
                                              comment['memberAvator'],
                                              width: 18,
                                              height: 18,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => const Icon(
                                                    Icons.person,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                            )
                                            : const Icon(
                                              Icons.person,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // 显示 nickname
                                          Text(
                                            comment['nickname'] ?? "匿名用户",
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          // VIP标识
                                          if (comment['goodObserve'] ==
                                              "2") ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                    vertical: 1,
                                                  ),
                                              color: Colors.orange,
                                              child: const Text(
                                                "V",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 8),
                                          Text(
                                            _parseCommentSpecs(
                                              comment['sec'] ?? "",
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // 星级评分
                                      Row(
                                        children: List.generate(5, (index) {
                                          // 将star转换为double类型，避免类型错误
                                          double starRating =
                                              double.tryParse(
                                                comment['star']?.toString() ??
                                                    '0',
                                              ) ??
                                              0;
                                          return Icon(
                                            index < starRating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 14,
                                            color: Colors.yellow,
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        comment['info'] ?? "",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 评论图片
                                if (comment['pictureUrl'] != null &&
                                    comment['pictureUrl'].isNotEmpty)
                                  // 处理评论图片：获取第一张并确保URL格式正确
                                  Image.network(
                                    _fixImageUrl('$baseUrl${comment['pictureUrl'].split(',').first.trim()}'),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
        ],
      ),
    );
  }

  // 解析评论中的规格数据
  String _parseCommentSpecs(dynamic specData) {
    // 使用print代替debug.log确保能看到输出
    try {
      if (specData is String) {
        
        // 直接解析外层JSON对象
        Map<String, dynamic> secObj;
        try {
          secObj = jsonDecode(specData);
        } catch (e) {
          // 处理可能的转义字符
          String processedStr = specData.replaceAll('\\"', '"');
          secObj = jsonDecode(processedStr);
        }

        // 获取sku字段
        dynamic skuField = secObj['sku'];


        if (skuField == null) {
          return "无规格信息";
        }

        List<dynamic> skuArray;
        
        // 如果sku是字符串，需要再次解析
        if (skuField is String) {
          try {
            skuArray = jsonDecode(skuField);
          } catch (e) {
            String processedSku = skuField.replaceAll('\\"', '"');
            skuArray = jsonDecode(processedSku);
          }
        } 
        // 如果已经是数组，直接使用
        else if (skuField is List<dynamic>) {
          skuArray = skuField;
        }
        // 其他类型
        else {
          return "无规格信息";
        }

        if (skuArray.isEmpty) {
          return "无规格信息";
        }

        // 提取skuValue
        List<String> values = [];
        for (var item in skuArray) {
          if (item is Map<String, dynamic> && item.containsKey('skuValue')) {
            String value = item['skuValue'].toString().trim();
            if (value.isNotEmpty) {
              values.add(value);
            }
          }
        }

        if (values.isEmpty) {
          return "无规格信息";
        }

        String result = values.join(' / ');
        return result;
      }
      
      // 如果specData不是字符串
      else {
        return "无规格信息";
      }
    } catch (e, stackTrace) {
      return "无规格信息";
    } finally {
      print("=== 规格信息解析结束 ===");
    }
  }

  // 底部操作栏
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.favorite,
              size: 28,
              color: isFavorite ? Colors.red : Colors.grey,
            ),
            onPressed: _toggleFavorite,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showBottomSheet(isBuyNow: false),
                child: Text(
                  AppLocalizations.of(context)?.translate('add_to_cart_kr') ??
                      "加入购物车",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showBottomSheet(isBuyNow: true),
                child: Text(
                  AppLocalizations.of(context)?.translate('buy_request_kr') ??
                      "请求购买",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 视频播放组件
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    // 创建视频播放器控制器
    _controller = VideoPlayerController.network(widget.videoUrl);

    // 初始化视频播放器
    _initializeVideoPlayerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // 释放视频播放器资源
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // 视频加载完成
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              // 播放/暂停按钮
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                      _isPlaying = false;
                    } else {
                      _controller.play();
                      _isPlaying = true;
                    }
                  });
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ],
          );
        } else {
          // 视频加载中
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
