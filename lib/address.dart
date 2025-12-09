import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dingbudaohang.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mall/config/service_url.dart';
import 'dart:developer' as developer;
import 'addressupdate.dart';
import 'app_localizations.dart';
import 'utils/http_util.dart';

class AddressUpdatePage extends StatelessWidget {
  final int addressId;
  const AddressUpdatePage({super.key, required this.addressId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)?.translate('update_address') ?? '修改地址')),
      body: Center(child: Text('${AppLocalizations.of(context)?.translate('update_address') ?? '修改地址'}，地址ID：$addressId')),
    );
  }
}

class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key});

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  List<Map<String, dynamic>> addressList = []; // 保存完整地址信息（含原始字段）
  bool _isLoading = true;
  String? _errorMsg;

  // 分页和加载更多相关变量
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  int _maxPage = 1; // 新增：最大可加载页数（由total计算得出）

  @override
  void initState() {
    super.initState();
    fetchAddressList();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // 新增：判断当前页码是否小于最大页数，才允许触发加载更多
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        _hasMore &&
        !_isLoading &&
        !_isLoadingMore &&
        _currentPage < _maxPage) { // 关键：限制最大页数
      _loadMore();
    }
  }

  void _loadMore() {
    // 新增：仅当当前页码小于最大页数时，才加载下一页
    if (_currentPage >= _maxPage) {
      setState(() => _isLoadingMore = false);
      return;
    }
    setState(() => _isLoadingMore = true);
    _currentPage++;
    fetchAddressList(isLoadMore: true);
  }

  // 加载地址列表（新增：根据total计算最大页数，限制加载）
  Future<void> fetchAddressList({bool isLoadMore = false}) async {
    setState(() {
      if (!isLoadMore) _isLoading = true;
      _errorMsg = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context)?.translate('please_login') ?? '请先登录');
      }

      final response = await HttpUtil.get(
        uaddresslist,
        queryParameters: {"pageNum": _currentPage, "pageSize": _pageSize},
      );

      if (response.data['code'] == 200) {
        List<dynamic> dataList = response.data['rows'] ?? [];
        // 新增：获取总条数total，计算最大可加载页数
        int total = response.data['total'] ?? 0; // 假设接口返回total字段（总数据条数）
        int maxPage = (total + _pageSize - 1) ~/ _pageSize; // 计算最大页数（向上取整）

        setState(() {
          _maxPage = maxPage; // 更新最大页数
          if (isLoadMore) {
            addressList.addAll(dataList.map((item) => _formatAddressItem(item)).toList());
          } else {
            addressList = dataList.map((item) => _formatAddressItem(item)).toList();
          }
          // 新增：判断是否还有更多（当前页码 < 最大页数）
          _hasMore = _currentPage < _maxPage;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        throw Exception(response.data['msg'] ?? (AppLocalizations.of(context)?.translate('get_address_list_failed') ?? '获取地址列表失败'));
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
        if (isLoadMore) _currentPage--;
      });
      developer.log('地址列表接口请求失败: $e');
      _showErrorSnackBar(_errorMsg!);
    }
  }

  // 格式化地址项（保持不变）
  Map<String, dynamic> _formatAddressItem(dynamic item) {
    List<String> tags = [];
    if (item['defaultAddress'] == "2") tags.add("默认");
    if (item['tagName'] != null && item['tagName'].toString().isNotEmpty) {
      tags.addAll((item['tagName'] as String).split(','));
    }
    return {
      "name": item['name'],
      "phone": item['tel'],
      "tags": tags,
      "address": " ${item['addressDetail']}",
      "isDefault": item['defaultAddress'] == "2",
      "userAddressId": item['userAddressId'],
      "original": {
        "tel": item['tel'],
        "tagName": item['tagName'] ?? "",
        "addressDetail": item['addressDetail'] ?? "",
        "defaultAddress": item['defaultAddress'] ?? "1",
        "tag": item['tag'] ?? "",
        "country": item['country'] ?? "",
        "state": item['state'] ?? "",
        "city": item['city'] ?? "",
        "district": item['district'] ?? "",
        "name": item['name'] ?? "",
      }
    };
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _maxPage = 1; // 下拉刷新时重置最大页数
    await fetchAddressList();
  }

  // 以下所有方法保持不变
  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _setAsDefault(int userAddressId) async {
    final addressItem = addressList.firstWhere(
      (item) => item['userAddressId'] == userAddressId,
      orElse: () => throw Exception("未找到地址信息"),
    );
    final originalData = addressItem['original'];

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('请先登录');
      }

      final updateData = {
        "userAddressId": userAddressId,
        "tel": originalData['tel'],
        "tagName": originalData['tagName'],
        "addressDetail": originalData['addressDetail'],
        "defaultAddress": "2",
        "tag": originalData['tag'],
        "country": originalData['country'],
        "state": originalData['state'],
        "city": originalData['city'],
        "district": originalData['district'],
        "name": originalData['name'],
      };

      final response = await HttpUtil.put(
        uoputedlist,
        data: updateData,
      );

      if (response.data['code'] == 200) {
        _showErrorSnackBar(AppLocalizations.of(context)?.translate('set_as_default_address_success') ?? "已设为默认地址");
        _currentPage = 1;
        _maxPage = 1; // 重置最大页数
        fetchAddressList();
      } else {
        throw Exception(response.data['msg'] ?? (AppLocalizations.of(context)?.translate('set_default_address_failed') ?? '设置默认地址失败'));
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _showErrorSnackBar(_errorMsg!);
      });
      developer.log('设置默认地址接口请求失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAddress(int userAddressId) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('请先登录');
      }

      final response = await HttpUtil.del(
        removelist.replaceAll('{userAddressIds}', userAddressId.toString()),
      );

      if (response.data['code'] == 200) {
        _showErrorSnackBar(AppLocalizations.of(context)?.translate('delete_success') ?? "删除成功");
        _currentPage = 1;
        _maxPage = 1; // 重置最大页数
        fetchAddressList();
      } else {
        throw Exception(response.data['msg'] ?? (AppLocalizations.of(context)?.translate('delete_address_failed') ?? '删除地址失败'));
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _showErrorSnackBar(_errorMsg!);
      });
      developer.log('删除地址接口请求失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyAddressToClipboard(String address) {
    Clipboard.setData(ClipboardData(text: address));
    _showErrorSnackBar(AppLocalizations.of(context)?.translate('address_copied_to_clipboard') ?? "地址已复制到剪贴板");
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          Container(
            height: 44,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)?.translate('address_book_management') ?? "地址簿管理",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddAddressPage()),
                    );
                    _currentPage = 1;
                    _maxPage = 1; // 重置最大页数
                    fetchAddressList();
                  },
                  child: Text(
                    AppLocalizations.of(context)?.translate('add_new_address') ?? "新增地址",
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : _errorMsg != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMsg!,
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _currentPage = 1;
                                _maxPage = 1; // 重置最大页数
                                fetchAddressList();
                              },
                              child: Text(AppLocalizations.of(context)?.translate('retry') ?? "重试"),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.red,
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: addressList.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == addressList.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: Text(AppLocalizations.of(context)?.translate('loading') ?? "加载中...", style: TextStyle(color: Colors.grey, fontSize: 14))),
                              );
                            }
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: _buildAddressItem(index, addressList[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressItem(int index, Map<String, dynamic> address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("${address['name']} ${address['phone']}", style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
            const SizedBox(width: 8),
            ...address['tags'].map((tag) {
              return Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: tag == "默认" ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tag, style: const TextStyle(fontSize: 12, color: Colors.white)),
              );
            }).toList(),
          ],
        ),
        const SizedBox(height: 8),
        Text(address['address'], style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
        const SizedBox(height: 8),
        Row(
          children: [
            if (address['isDefault'])
               Row(
                children: [
                    Checkbox(value: true, onChanged: null, activeColor: Colors.red, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    Text(AppLocalizations.of(context)?.translate('already_default') ?? "已默认", style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                  ],
              )
            else
              Row(
                children: [
                  Checkbox(
                      value: false,
                      onChanged: (value) {
                        if (value == true) _setAsDefault(address['userAddressId']);
                      },
                      activeColor: Colors.red,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(AppLocalizations.of(context)?.translate('set_as_default') ?? "设为默认", style: TextStyle(fontSize: 14, color: Color(0xFF333333))),
                ],
              ),
            const Spacer(),
            _buildActionButton(AppLocalizations.of(context)?.translate('delete') ?? "删除", address['userAddressId']),
            const SizedBox(width: 8),
            _buildActionButton(AppLocalizations.of(context)?.translate('copy') ?? "复制", address['userAddressId']),
            const SizedBox(width: 8),
            _buildActionButton(AppLocalizations.of(context)?.translate('edit') ?? "修改", address['userAddressId']),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, int userAddressId) {
    return TextButton(
      onPressed: () async {
        switch (text) {
          case "修改":
          case "edit":
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddAddressPage(userAddressId: userAddressId)),
            );
            _currentPage = 1;
            _maxPage = 1; // 重置最大页数
            fetchAddressList();
            break;
          case "删除":
          case "delete":
            await _deleteAddress(userAddressId);
            break;
          case "复制":
          case "copy":
            String address = addressList.firstWhere((item) => item['userAddressId'] == userAddressId)['address'];
            _copyAddressToClipboard(address);
            break;
        }
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(60, 28),
        backgroundColor: const Color(0xFFCCCCCC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 14),
      ),
      child: Text(text),
    );
  }
}