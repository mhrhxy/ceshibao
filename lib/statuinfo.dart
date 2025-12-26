import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'dingbudaohang.dart';
import './config/service_url.dart';
import './utils/http_util.dart';

class MemberInfo {
  final int memberId;
  final String memberName;
  final String nickName;
  final String email;
  final String phoneNumber;
  final String sex;
  final String avatar;
  final String? birthday;

  MemberInfo({
    required this.memberId,
    required this.memberName,
    required this.nickName,
    required this.email,
    required this.phoneNumber,
    required this.sex,
    required this.avatar,
    this.birthday,
  });

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    return MemberInfo(
      memberId: json['memberId'] ?? 0,
      memberName: json['memberName'] ?? '',
      nickName: json['nickName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      sex: json['sex'] ?? '2',
      avatar: json['avatar'] ?? '',
      birthday: json['birthday'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'nickName': nickName,
      'email': email,
      'phoneNumber': phoneNumber,
      'sex': sex,
      'avatar': avatar,
      'birthday': birthday,
    };
  }

  MemberInfo copyWith({
    String? sex,
    String? birthday,
    String? nickName,
    String? avatar,
    String? phoneNumber,
  }) {
    return MemberInfo(
      memberId: memberId,
      memberName: memberName,
      nickName: nickName ?? this.nickName,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      sex: sex ?? this.sex,
      avatar: avatar ?? this.avatar,
      birthday: birthday ?? this.birthday,
    );
  }
}

class AccountInfoChangePage extends StatefulWidget {
  const AccountInfoChangePage({super.key});

  @override
  State<AccountInfoChangePage> createState() => _AccountInfoChangePageState();
}

class _AccountInfoChangePageState extends State<AccountInfoChangePage> {
  MemberInfo? _memberInfo;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocalMemberInfo();
  }

  Future<void> _loadLocalMemberInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memberInfoJson = prefs.getString('member_info');

      if (memberInfoJson == null || memberInfoJson.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.translate('please_login') ?? '请先登录')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, dynamic> jsonData = json.decode(memberInfoJson);
      setState(() {
        _memberInfo = MemberInfo.fromJson(jsonData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.translate('load_failed') ?? '获取信息失败'}：${e.toString()}')),
        );
      }
    }
  }

  // 接口调用：仅在成功时返回，失败时抛出异常
  Future<void> _updateMemberInfoToServer(MemberInfo updatedInfo) async {
    if (_isSubmitting || updatedInfo.memberId == 0) return;
    _isSubmitting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context)?.translate('please_login') ?? '请先登录');
      }

      final params = {
        "memberId": updatedInfo.memberId,
        "nickName": updatedInfo.nickName,
        "phoneNumber": updatedInfo.phoneNumber,
        "sex": updatedInfo.sex,
        "avatar": updatedInfo.avatar,
        "birthday": updatedInfo.birthday,
      };

      final response = await HttpUtil.put(
        updatememberinfo,
        data: params
      );

      if (response.data['code'] != 200) {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('update_failed') ?? '修改失败');
      }
    } catch (e) {
      rethrow; // 抛出异常，让调用方处理
    } finally {
      _isSubmitting = false;
    }
  }

  // 保存逻辑：先调用接口，成功后再更新本地
  Future<void> _saveMemberInfo(MemberInfo updatedInfo) async {
    if (_memberInfo == null) return;

    try {
      // 1. 先调用接口，接口失败直接进入catch
      await _updateMemberInfoToServer(updatedInfo);

      // 2. 接口成功后，再更新本地存储和UI
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('member_info', json.encode(updatedInfo.toJson()));
      
      setState(() => _memberInfo = updatedInfo);

      // 3. 提示成功
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('update_success') ?? '修改成功')),
      );
    } catch (e) {
      // 接口失败：不修改本地数据，仅提示失败
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)?.translate('update_failed') ?? '修改失败'}：${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 昵称修改弹窗
  void _showNicknameDialog() {
    if (_memberInfo == null) return;
    _nicknameController.text = _memberInfo!.nickName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('edit_nickname') ?? '修改昵称'),
        content: TextField(
          controller: _nicknameController,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)?.translate('enter_nickname') ?? '请输入昵称',
            border: const OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.translate('cancel') ?? '取消'),
          ),
          TextButton(
            onPressed: _submitNickname,
            child: Text(AppLocalizations.of(context)?.translate('confirm') ?? '确认'),
          ),
        ],
      ),
    );
  }

  // 提交新昵称
  void _submitNickname() {
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('nickname_not_empty') ?? '昵称不能为空')),
      );
      return;
    }
    
    Navigator.pop(context);
    final updatedInfo = _memberInfo!.copyWith(nickName: newNickname);
    _saveMemberInfo(updatedInfo);
  }

  // 性别选择弹窗
  void _showGenderDialog() {
    if (_memberInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.translate('select_gender') ?? '选择性别'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)?.translate('male') ?? '男'),
              leading: Radio<String>(
                value: '0',
                groupValue: _memberInfo!.sex,
                onChanged: (value) => _onGenderSelected(value),
              ),
              onTap: () => _onGenderSelected('0'),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)?.translate('female') ?? '女'),
              leading: Radio<String>(
                value: '1',
                groupValue: _memberInfo!.sex,
                onChanged: (value) => _onGenderSelected(value),
              ),
              onTap: () => _onGenderSelected('1'),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)?.translate('secret') ?? '保密'),
              leading: Radio<String>(
                value: '2',
                groupValue: _memberInfo!.sex,
                onChanged: (value) => _onGenderSelected(value),
              ),
              onTap: () => _onGenderSelected('2'),
            ),
          ],
        ),
      ),
    );
  }

  void _onGenderSelected(String? value) {
    if (value == null || _memberInfo == null) return;
    Navigator.pop(context);
    final updatedInfo = _memberInfo!.copyWith(sex: value);
    _saveMemberInfo(updatedInfo);
  }

  // 生日选择器
  void _showBirthdayPicker() async {
    if (_memberInfo == null) return;

    DateTime initialDate = DateTime.now();
    if (_memberInfo!.birthday != null && _memberInfo!.birthday!.isNotEmpty) {
      try {
        final parts = _memberInfo!.birthday!.split('-');
        if (parts.length == 2) {
          final month = int.parse(parts[0]);
          final day = int.parse(parts[1]);
          initialDate = DateTime(2000, month, day);
        }
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.translate('select_birthday') ?? '选择出生日期',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          child!,
        ],
      ),
    );

    if (picked != null) {
      final formatted = DateFormat('MM-dd').format(picked);
      final updatedInfo = _memberInfo!.copyWith(birthday: formatted);
      _saveMemberInfo(updatedInfo);
    }
  }

  String _getGenderText() {
    if (_memberInfo == null) {
      return AppLocalizations.of(context)?.translate('secret') ?? '保密';
    }
    switch (_memberInfo!.sex) {
      case '0':
        return AppLocalizations.of(context)?.translate('male') ?? '男';
      case '1':
        return AppLocalizations.of(context)?.translate('female') ?? '女';
      case '2':
        return AppLocalizations.of(context)?.translate('secret') ?? '保密';
      default:
        return AppLocalizations.of(context)?.translate('secret') ?? '保密';
    }
  }

  String _getAvatarUrl() {
    if (_memberInfo?.avatar == null || _memberInfo!.avatar.isEmpty) {
      return 'https://via.placeholder.com/48';
    }
    if (_memberInfo!.avatar.startsWith('http')) {
      return _memberInfo!.avatar;
    } else {
      return '$baseUrl${_memberInfo!.avatar}';
    }
  }

  // 选择并上传头像
  Future<void> _pickAndUploadAvatar() async {
    if (_memberInfo == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      // 选择图片
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // 图片质量
        maxWidth: 500, // 最大宽度
        maxHeight: 500, // 最大高度
      );

      if (image == null) return; // 用户取消选择

      // 上传图片到服务器
      final String avatarUrl = await _uploadAvatarImage(image);

      // 更新本地用户信息
      final updatedInfo = _memberInfo!.copyWith(avatar: avatarUrl);
      await _saveMemberInfo(updatedInfo);

      // 提示上传成功
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate('avatar_upload_success') ?? '头像上传成功')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)?.translate('avatar_upload_failed') ?? '头像上传失败'}：${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 上传头像图片到服务器
  Future<String> _uploadAvatarImage(XFile image) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 构建FormData
      FormData formData;
      if (kIsWeb) {
        // Web端使用MultipartFile.fromBytes
        final bytes = await image.readAsBytes();
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: image.name,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        });
      } else {
        // 移动端使用MultipartFile.fromFile
        formData = FormData.fromMap({
          'file': MultipartFile.fromFileSync(
            image.path,
            filename: image.name,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        });
      }

      // 调用上传接口
      final response = await HttpUtil.post(
        uploadFileUrl,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data['code'] != 200) {
        throw Exception(response.data['msg'] ?? AppLocalizations.of(context)?.translate('upload_failed') ?? '上传失败');
      }

      // 返回上传成功后的图片URL
      final String imageUrl = response.data['url'] ?? '';
      if (imageUrl.isEmpty) {
        throw Exception(AppLocalizations.of(context)?.translate('upload_failed') ?? '上传失败');
      }

      return imageUrl;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            AppLocalizations.of(context)?.translate('account_info') ?? '账户信息确认/变更',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: ListView(
                      children: [
                        _buildInfoItem(
                          title: AppLocalizations.of(context)?.translate('avatar') ?? '头像',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  _getAvatarUrl(),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.person_outline, color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                            ],
                          ),
                          isEditable: true,
                          onTap: _pickAndUploadAvatar,
                        ),
                        const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),
                        _buildInfoItem(
                          title: AppLocalizations.of(context)?.translate('account_name') ?? '账号名',
                          content: _memberInfo?.memberName ?? '',
                          isEditable: false,
                        ),
                        const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),
                        _buildInfoItem(
                          title: AppLocalizations.of(context)?.translate('nickname') ?? '昵称',
                          content: _memberInfo?.nickName ?? '',
                          isEditable: true,
                          onTap: _showNicknameDialog,
                        ),
                        const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),
                        _buildInfoItem(
                          title: AppLocalizations.of(context)?.translate('gender') ?? '性别',
                          content: _getGenderText(),
                          isEditable: true,
                          onTap: _showGenderDialog,
                        ),
                        const Divider(height: 1, indent: 0, color: Color(0xFFEEEEEE)),
                        _buildInfoItem(
                          title: AppLocalizations.of(context)?.translate('birth_date') ?? '出生日期',
                          content: _memberInfo?.birthday ?? 
                              AppLocalizations.of(context)?.translate('please_fill') ?? '请填写',
                          isEditable: true,
                          onTap: _showBirthdayPicker,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoItem({
    required String title,
    String? content,
    Widget? trailing,
    required bool isEditable,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      trailing: trailing ?? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (content != null) Text(
            content,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          if (isEditable) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: isEditable ? onTap : null,
    );
  }
}