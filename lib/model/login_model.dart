// To parse this JSON data, do
//
//     final loginModel = loginModelFromJson(jsonString);

import 'dart:convert';

LoginModel loginModelFromJson(String str) => LoginModel.fromJson(json.decode(str));

String loginModelToJson(LoginModel data) => json.encode(data.toJson());

class LoginModel {
  int code;
  String msg;  // 接口返回的是"msg"而非"message"
  String token; // 接口直接在根节点返回token，无需data层

  LoginModel({
    required this.code,
    required this.msg,
    required this.token,
  });

  // 从JSON解析，匹配接口字段
  factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
        code: json["code"] ?? -1, // 增加默认值，避免null
        msg: json["msg"] ?? "未知信息", // 接口返回"msg"字段
        token: json["token"] ?? "", // 接口根节点的token字段
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "msg": msg,
        "token": token,
      };
}
    