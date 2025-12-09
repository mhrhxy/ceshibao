import 'package:flutter/material.dart';
import 'utils/http_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'package:daum_postcode_view/daum_postcode_view.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'dart:developer' as developer;
import 'package:flutter_mall/app_localizations.dart'; // 导入国际化工具类

class AddAddressPage extends StatefulWidget {
  final int? userAddressId; // 可选参数：有则为修改，无则为新增
  const AddAddressPage({super.key, this.userAddressId});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  // 表单控制器（新增/修改时用于填充/提交数据）
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController =
      TextEditingController();
  final TextEditingController _customTagController = TextEditingController();

  // 状态变量
  String _zipcode = '';
  bool _isDefaultAddress = true;
  String? _selectedTag;
  List<String> _tags = ['学校', '家'];
  bool _isCustomTagEditing = false;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.userAddressId != null) {
      _fetchAddressDetail();
    }
  }

  // 加载地址详情（修改模式）
  Future<void> _fetchAddressDetail() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          AppLocalizations.of(context)?.translate('please_login') ?? '请先登录',
        );
      }

      // 使用HttpUtil处理HTTP请求，无需手动创建Dio实例和设置Authorization头

      final url = userAddress.replaceAll(
        '{userAddressId}',
        widget.userAddressId.toString(),
      );
      final response = await HttpUtil.get(url);

      if (response.data['code'] == 200) {
        final data = response.data['data'] ?? {};
        _fillFormData(data);
      } else {
        throw Exception(
          response.data['msg'] ??
              (AppLocalizations.of(
                    context,
                  )?.translate('get_address_detail_failed') ??
                  '获取地址详情失败'),
        );
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
      developer.log(
        '${AppLocalizations.of(context)?.translate('get_address_detail_failed') ?? '获取地址详情失败'}: $e',
      );
      _showErrorSnackBar(_errorMsg!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 填充表单数据（修改模式专用）
  void _fillFormData(Map<String, dynamic> data) {
    setState(() {
      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['tel'] ?? '';
      _zipcode = data['zipcode'] ?? '';

      // 合并地址详情（兼容历史数据格式）
      _addressController.text = data['addressDetail'] ?? '';
      _detailAddressController.text = ''; // 历史数据无详细地址拆分，清空

      _isDefaultAddress = data['defaultAddress'] == "2";

      List<String> tags = [];
      if (data['defaultAddress'] == "2") tags.add("默认");
      if (data['tagName'] != null && data['tagName'].toString().isNotEmpty) {
        tags.addAll((data['tagName'] as String).split(','));
      }
      _tags = [
        AppLocalizations.of(context)?.translate('school') ?? '学校',
        AppLocalizations.of(context)?.translate('home_address') ?? '家',
        ...tags.where((t) => !['学校', '家', '默认'].contains(t)),
      ];
      _selectedTag = tags.isNotEmpty ? tags.first : null;
    });
  }

  Future<void> _openDaumPostcode() async {
    // 使用showDialog显示中间悬浮弹窗
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.98, // 进一步增大宽度
              height: MediaQuery.of(context).size.height * 0.9, // 进一步增大高度
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 5,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 弹窗标题
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('search_postcode') ??
                              '邮编搜索',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // 邮编搜索组件 - 使用Expanded确保占满剩余空间并支持滚动
                  Expanded(
                    flex: 1,
                    child: DaumPostcodeView(
                      onComplete: (model) {
                        Navigator.pop(context);
                        setState(() {
                          _zipcode = model.zonecode ?? '';
                          _addressController.text = model.address ?? '';
                          _detailAddressController.text =
                              model.buildingName ?? '';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 切换标签选中状态
  void _toggleTag(String tag) {
    setState(() {
      if (_isCustomTagEditing) {
        _isCustomTagEditing = false;
        _customTagController.clear();
      }
      _selectedTag = _selectedTag == tag ? null : tag;
    });
  }

  // 提交自定义标签
  void _submitCustomTag() {
    final newTag = _customTagController.text.trim();
    if (newTag.isNotEmpty && !_tags.contains(newTag) && newTag.length <= 4) {
      setState(() {
        _tags.add(newTag);
        _selectedTag = newTag;
        _isCustomTagEditing = false;
        _customTagController.clear();
      });
    }
  }

  // 提交表单（新增/修改）
  Future<void> _submitForm() async {
    if (_nameController.text.isEmpty) {
      _showErrorSnackBar(
        AppLocalizations.of(context)?.translate('input_consignee') ?? '请输入收货人',
      );
      return;
    }
    if (_phoneController.text.isEmpty) {
      _showErrorSnackBar(
        AppLocalizations.of(context)?.translate('input_phone') ?? '请输入手机号',
      );
      return;
    }
    if (_addressController.text.isEmpty) {
      _showErrorSnackBar(
        AppLocalizations.of(context)?.translate('select_address') ?? '请选择地址',
      );
      return;
    }
    if (_selectedTag == null) {
      _showErrorSnackBar(
        AppLocalizations.of(context)?.translate('select_tag') ?? '请选择标签',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          AppLocalizations.of(context)?.translate('please_login') ?? '请先登录',
        );
      }
      // 构造提交数据：移除国家/省/市/区，合并地址到addressDetail
      final submitData = {
        "name": _nameController.text,
        "tel": _phoneController.text,
        "addressDetail":
            "${_addressController.text} ${_detailAddressController.text}", // 合并基础地址和详细地址
        "defaultAddress": _isDefaultAddress ? "2" : "1",
        "tagName": _selectedTag, // 标签名称（若需多标签可改为拼接字符串）
        "tag": "", // 标签ID（按需调整）
        "zipcode": _zipcode,
        if (widget.userAddressId != null) "userAddressId": widget.userAddressId,
      };

      if (widget.userAddressId == null) {
        await HttpUtil.post(uoputedlist, data: submitData);
      } else {
        await HttpUtil.put(uoputedlist, data: submitData);
      }

      _showErrorSnackBar(
        widget.userAddressId == null
            ? (AppLocalizations.of(context)?.translate('add_address_success') ??
                '新增地址成功')
            : (AppLocalizations.of(
                  context,
                )?.translate('update_address_success') ??
                '修改地址成功'),
      );
      Navigator.pop(context, true);
    } catch (e) {
      final errorMsg = e.toString();
      _showErrorSnackBar(
        widget.userAddressId == null
            ? '${AppLocalizations.of(context)?.translate('add_address_failed') ?? '新增地址失败'}：$errorMsg'
            : '${AppLocalizations.of(context)?.translate('update_address_failed') ?? '修改地址失败'}：$errorMsg',
      );
      developer.log(
        '${AppLocalizations.of(context)?.translate('submit_address_failed') ?? '提交地址失败'}: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: const Color(0xFFF2F3F5),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.red),
              )
              : Column(
                children: [
                  Container(
                    height: 44,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.userAddressId == null
                              ? (AppLocalizations.of(
                                    context,
                                  )?.translate('add_address') ??
                                  '新增地址')
                              : (AppLocalizations.of(
                                    context,
                                  )?.translate('update_address') ??
                                  '修改地址'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('consignee') ??
                                          '收货人',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _nameController,
                                        decoration: InputDecoration(
                                          hintText:
                                              AppLocalizations.of(
                                                context,
                                              )?.translate('please_input') ??
                                              '请输入',
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0xFFEEEEEE),
                                            ),
                                          ),
                                          hintStyle: TextStyle(
                                            color: Color(0xFF999999),
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('phone') ??
                                          '手机号',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        decoration: InputDecoration(
                                          hintText:
                                              AppLocalizations.of(
                                                context,
                                              )?.translate(
                                                'phone_format_example',
                                              ) ??
                                              '010-12345678',
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0xFFEEEEEE),
                                            ),
                                          ),
                                          hintStyle: TextStyle(
                                            color: Color(0xFF999999),
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('address') ??
                                          '地址',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _addressController,
                                        decoration: InputDecoration(
                                          hintText:
                                              AppLocalizations.of(
                                                context,
                                              )?.translate('select_address') ??
                                              '请选择地址',
                                          border: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Color(0xFFEEEEEE),
                                            ),
                                          ),
                                          hintStyle: TextStyle(
                                            color: Color(0xFF999999),
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                        readOnly: true,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _openDaumPostcode,
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Color(0xFFCCCCCC),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        minimumSize: const Size(80, 30),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(
                                              context,
                                            )?.translate('search_postcode') ??
                                            '搜索邮编',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)?.translate(
                                            'set_as_default_address',
                                          ) ??
                                          '设置为默认地址',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF333333),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Checkbox(
                                      value: _isDefaultAddress,
                                      activeColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _isDefaultAddress = value ?? true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  AppLocalizations.of(context)?.translate(
                                        'note_default_address_priority',
                                      ) ??
                                      '注：下单时优先使用该地址',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF999999),
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFEEEEEE),
                                  indent: 16,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('tag') ??
                                          '标签',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        ..._tags.map(
                                          (tag) => GestureDetector(
                                            onTap: () => _toggleTag(tag),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      _selectedTag == tag
                                                          ? Colors.red
                                                          : Color(0xFFCCCCCC),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    color:
                                                        _selectedTag == tag
                                                            ? Colors.red
                                                            : Colors.black,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _isCustomTagEditing = true;
                                            });
                                          },
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Color(0xFFCCCCCC),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              child: Text(
                                                AppLocalizations.of(
                                                      context,
                                                    )?.translate('custom') ??
                                                    '自定义',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (_isCustomTagEditing)
                                  Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _customTagController,
                                              decoration: InputDecoration(
                                                hintText:
                                                    AppLocalizations.of(
                                                      context,
                                                    )?.translate(
                                                      'input_tag_max_4_chars',
                                                    ) ??
                                                    '输入标签（最多4字）',
                                                border: OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                    color: Color(0xFFCCCCCC),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.all(
                                                        Radius.circular(4),
                                                      ),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              maxLength: 4,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                              onSubmitted:
                                                  (_) => _submitCustomTag(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.userAddressId == null
                            ? (AppLocalizations.of(
                                  context,
                                )?.translate('confirm_add') ??
                                '确认新增')
                            : (AppLocalizations.of(
                                  context,
                                )?.translate('confirm_update') ??
                                '确认修改'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
