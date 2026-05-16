import '../http/api_response.dart';

class ManagerInfo {
  ManagerInfo({
    this.accountId,
    this.name,
    this.email,
    this.phone,
    this.avatar,
  });

  final String? accountId;
  final String? name;
  final String? email;
  final String? phone;
  final String? avatar;

  factory ManagerInfo.fromJson(Map<String, dynamic> json) {
    return ManagerInfo(
      accountId: jsonStr(json['accountId']),
      name: jsonStr(json['name']),
      email: jsonStr(json['email']),
      phone: jsonStr(json['phone']),
      avatar: jsonStr(json['avatar']),
    );
  }
}
