// lib/model/member_info_model.dart
class MemberInfoModel {
  final int memberId;
  final String nickName;
  final String memberName;
  final String email;
  final String phoneNumber;
  final String sex;
  final String avatar;
  final String? birthday;

  MemberInfoModel({
    required this.memberId,
    required this.nickName,
    required this.memberName,
    required this.email,
    required this.phoneNumber,
    required this.sex,
    required this.avatar,
    this.birthday,
  });

  // 从JSON解析
  factory MemberInfoModel.fromJson(Map<String, dynamic> json) {
    return MemberInfoModel(
      memberId: json['memberId'] ?? 0,
      nickName: json['nickName'] ?? '',
      memberName: json['memberName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      sex: json['sex'] ?? '2',
      avatar: json['avatar'] ?? '',
      birthday: json['birthday'],
    );
  }

  // 转为JSON（用于本地存储）
  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'nickName': nickName,
      'memberName': memberName,
      'email': email,
      'phoneNumber': phoneNumber,
      'sex': sex,
      'avatar': avatar,
      'birthday': birthday,
    };
  }
}