import 'package:flutter/material.dart';
import 'package:flutter_mall/model/toast_model.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_mall/app_localizations.dart';
import 'dingbudaohang.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './config/service_url.dart';
import './utils/http_util.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart'; 
class partylogin extends StatefulWidget {
  const partylogin({super.key});

  @override
  State<partylogin> createState() => _partyloginState();
}

class _partyloginState extends State<partylogin> {
  List<dynamic> _thirdAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchThirdLoginAccounts();
  }

  Future<void> _fetchThirdLoginAccounts() async {
    try {
      final response = await HttpUtil.get(thirdLoginMethodDetailUrl);
      if (response.data['code'] == 200 && response.data['data'] != null) {
        setState(() {
          // 检查返回的数据类型，如果是单个对象则转换为列表
          if (response.data['data'] is List) {
            _thirdAccounts = response.data['data'];
          } else if (response.data['data'] is Map) {
            _thirdAccounts = [response.data['data']];
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to fetch third login accounts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getDisplayName(Map<String, dynamic> account) {
    if (account['thirdName'] != null &&
        account['thirdName'].toString().isNotEmpty) {
      return account['thirdName'].toString();
    } else if (account['thirdNickname'] != null &&
        account['thirdNickname'].toString().isNotEmpty) {
      return account['thirdNickname'].toString();
    }
    return '待绑定';
  }

  Future<void> _handleThirdPartyLogin(Map<String, dynamic> account) async {
    // 只有当thirdTypeName等于"Naver第三方登录"时才执行Naver登录逻辑
    if (account['thirdTypeName'] == 'Naver第三方登录') {
      try {
        final result = await FlutterNaverLogin.logIn();
        //获取当前有效的 accessToken
        final accessToken = await FlutterNaverLogin.getCurrentAccessToken(); //将 result 转换为 JSON 字符串
        
        // 准备绑定接口参数
        final bindParams = {
          "id": result.account?.id,
          "nickname": result.account?.nickname,
          "name": result.account?.name,
          "email": result.account?.email,
          "gender": result.account?.gender,
          "age": result.account?.age,
          "mobile": result.account?.mobile?.replaceAll('-', ''),
          "accessToken": accessToken.accessToken,
        };  
        ToastUtil.showCustomToast(context,'登录成功: $bindParams');
        
        // 调用绑定接口
        final bindResponse = await HttpUtil.post(bindNaverAccountUrl, data: bindParams);
        
        if (bindResponse.data['code'] == 200) {
          // 绑定成功后刷新账号列表
          await _fetchThirdLoginAccounts();
          
          // 在成功后展示一个对话框
          ToastUtil.showCustomToast(context,'绑定成功');
        } else {
          // 绑定失败
          ToastUtil.showCustomToast(context,'绑定失败: ${bindResponse.data['message']}');
        }
      } catch (e) {
        print('Error during Naver login: $e');
        ToastUtil.showCustomToast(context,'登录失败: $e');
      }
    } else  {
      print('dianidandian');
        final authToken = await UserApi.instance.loginWithKakaoTalk();
        print("Kakao login success");

        print("Access Token: ${authToken.accessToken}");
                        // 获取用户信息
        final user = await UserApi.instance.me();
        
        // 准备绑定接口参数
       final loginParams = {
        "id":user.id,//第三方ID
        "kakaoAccount":{
           "email":user.kakaoAccount?.email,//邮箱
           "profile":{
               "nickname":user.kakaoAccount?.profile?.nickname//昵称
          }
         }
       };
        ToastUtil.showCustomToast(context,'登录成功: $loginParams');
        // 调用绑定接口
        final bindResponse = await HttpUtil.post(bindKakaoAccountUrl, data: loginParams);
        if (bindResponse.data['code'] == 200) {
          // 绑定成功后刷新账号列表
          await _fetchThirdLoginAccounts();
          // 在成功后展示一个对话框
          ToastUtil.showCustomToast(context,'绑定成功');
        } else {
          // 绑定失败
          ToastUtil.showCustomToast(context,'绑定失败: ${bindResponse.data['message']}');
        }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 返回栏 + 标题（样式不变）
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
                      '第三方登录',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 48.w),
              ],
            ),
          ),

          // 第三方账号列表
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: _thirdAccounts.length,
                      itemBuilder: (context, index) {
                        final account = _thirdAccounts[index];
                        return GestureDetector(
                          onTap: () => _handleThirdPartyLogin(account),
                          child: Container(
                            color: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 16.h,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  account['thirdTypeName'].toString(),
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _getDisplayName(account),
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 16.sp,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16.r,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
