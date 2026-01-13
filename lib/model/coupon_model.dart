// To parse this JSON data, do
//
//     final couponModel = couponModelFromJson(jsonString);

import 'dart:convert';

CouponModel couponModelFromJson(String str) => CouponModel.fromJson(json.decode(str));

String couponModelToJson(CouponModel data) => json.encode(data.toJson());

class CouponModel {
  int code;
  String message;
  List<CouponData> data;

  CouponModel({
    required this.code,
    required this.message,
    required this.data,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) => CouponModel(
        code: json["code"] is String ? int.tryParse(json["code"]) ?? 0 : json["code"] ?? 0,
        message: json["message"] ?? '',
        data: List<CouponData>.from(json["data"].map((x) => CouponData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class CouponData {
  int id;
  int type;
  String name;
  int platform;
  int count;
  double amount;
  double returnAmount; // 新增字段：满减金额或折扣百分比
  int perLimit;
  int minPoint;
  String startTime;
  String endTime;
  int useType;
  int publishCount;
  int useCount;
  int receiveCount;
  String enableTime;

  CouponData({
    required this.id,
    required this.type,
    required this.name,
    required this.platform,
    required this.count,
    required this.amount,
    required this.returnAmount, // 添加到构造函数
    required this.perLimit,
    required this.minPoint,
    required this.startTime,
    required this.endTime,
    required this.useType,
    required this.publishCount,
    required this.useCount,
    required this.receiveCount,
    required this.enableTime,
  });

  factory CouponData.fromJson(Map<String, dynamic> json) => CouponData(
        id: json["id"] is String ? int.tryParse(json["id"]) ?? 0 : json["id"] ?? 0,
        type: json["type"] is String ? int.tryParse(json["type"]) ?? 0 : json["type"] ?? 0,
        name: json["name"] ?? '',
        platform: json["platform"] is String ? int.tryParse(json["platform"]) ?? 0 : json["platform"] ?? 0,
        count: json["count"] is String ? int.tryParse(json["count"]) ?? 0 : json["count"] ?? 0,
        amount: json["amount"] is String ? double.tryParse(json["amount"]) ?? 0 : json["amount"] ?? 0,
        returnAmount: json["returnAmount"] is String ? double.tryParse(json["returnAmount"]) ?? 0 : json["returnAmount"] ?? 0, // 从JSON解析
        perLimit: json["perLimit"] is String ? int.tryParse(json["perLimit"]) ?? 0 : json["perLimit"] ?? 0,
        minPoint: json["minPoint"] is String ? int.tryParse(json["minPoint"]) ?? 0 : json["minPoint"] ?? 0,
        startTime: json["startTime"] ?? '',
        endTime: json["endTime"] ?? '',
        useType: json["useType"] is String ? int.tryParse(json["useType"]) ?? 0 : json["useType"] ?? 0,
        publishCount: json["publishCount"] is String ? int.tryParse(json["publishCount"]) ?? 0 : json["publishCount"] ?? 0,
        useCount: json["useCount"] is String ? int.tryParse(json["useCount"]) ?? 0 : json["useCount"] ?? 0,
        receiveCount: json["receiveCount"] is String ? int.tryParse(json["receiveCount"]) ?? 0 : json["receiveCount"] ?? 0,
        enableTime: json["enableTime"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "type": type,
        "name": name,
        "platform": platform,
        "count": count,
        "amount": amount,
        "returnAmount": returnAmount, // 添加到toJson
        "perLimit": perLimit,
        "minPoint": minPoint,
        "startTime": startTime,
        "endTime": endTime,
        "useType": useType,
        "publishCount": publishCount,
        "useCount": useCount,
        "receiveCount": receiveCount,
        "enableTime": enableTime,
      };

  // 从API返回的JSON创建CouponData对象
  factory CouponData.fromApiJson(Map<String, dynamic> json) {
    // 确定优惠券类型：满减券或折扣券
    // 修复类型转换：确保type是int类型
    dynamic typeValue = json['type'];
    int type = 0;
    if (typeValue is String) {
      type = int.tryParse(typeValue) ?? ((json['returnAmount'] ?? 0) > 0 ? 1 : 2);
    } else {
      type = typeValue ?? ((json['returnAmount'] ?? 0) > 0 ? 1 : 2);
    }
    
    // 修复amount类型转换
    dynamic amountValue = json['amount'];
    double amount = 0;
    if (amountValue is String) {
      amount = double.tryParse(amountValue) ?? 0;
    } else {
      amount = amountValue ?? 0;
    }
    
    // 修复returnAmount类型转换
    dynamic returnAmountValue = json['returnAmount'];
    double returnAmount = 0;
    if (returnAmountValue is String) {
      returnAmount = double.tryParse(returnAmountValue) ?? 0;
    } else {
      returnAmount = returnAmountValue ?? 0;
    }
    
    // 修复couponId类型转换
    dynamic couponIdValue = json['couponId'];
    int couponId = 0;
    if (couponIdValue is String) {
      couponId = int.tryParse(couponIdValue) ?? 0;
    } else {
      couponId = couponIdValue ?? 0;
    }
    
    return CouponData(
      id: couponId,
      type: type,
      name: _generateCouponName(json),
      platform: 1, // 默认为1，可根据实际业务调整
      count: 1, // 默认为1，可根据实际业务调整
      amount: amount, // 满多少金额
      returnAmount: returnAmount, // 满减金额或折扣百分比
      perLimit: 1, // 默认为1，可根据实际业务调整
      minPoint: amount.toInt(), // 满多少
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      useType: 0, // 默认为未使用，可根据实际业务调整
      publishCount: 1000, // 默认为1000，可根据实际业务调整
      useCount: 0, // 默认为0，可根据实际业务调整
      receiveCount: 1, // 默认为1，可根据实际业务调整
      enableTime: json['startTime'] ?? '',
    );
  }
  
  // 根据API数据生成优惠券名称
  static String _generateCouponName(Map<String, dynamic> json) {
    // 修复type类型转换
    dynamic typeValue = json['type'];
    int type = 0;
    if (typeValue is String) {
      type = int.tryParse(typeValue) ?? ((json['returnAmount'] ?? 0) > 0 ? 1 : 2);
    } else {
      type = typeValue ?? ((json['returnAmount'] ?? 0) > 0 ? 1 : 2);
    }
    
    // 修复amount类型转换
    dynamic amountValue = json['amount'];
    double amount = 0;
    if (amountValue is String) {
      amount = double.tryParse(amountValue) ?? 0;
    } else {
      amount = amountValue ?? 0;
    }
    
    // 修复returnAmount类型转换
    dynamic returnAmountValue = json['returnAmount'];
    double returnAmount = 0;
    if (returnAmountValue is String) {
      returnAmount = double.tryParse(returnAmountValue) ?? 0;
    } else {
      returnAmount = returnAmountValue ?? 0;
    }
    
    if (type == 1) { // 满减券
      return '满${amount.toInt()}减${returnAmount.toInt()}元优惠券';
    } else { // 折扣券
      double discount = returnAmount / 10; // 转换为折扣，例如90 → 9折
      return '满${amount.toInt()}打${discount}折优惠券';
    }
  }
}