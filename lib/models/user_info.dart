import '../http/api_response.dart';

class UserInfo {
  UserInfo({
    required this.id,
    this.email,
    this.name,
    this.phone,
    this.address,
    this.imageUrl,
    this.accountId,
    this.roleId,
    this.roleName,
    this.roleCode,
    this.status,
    this.branchName,
    this.merchantName,
    this.beaconUuid,
    this.merchantId,
  });

  final int id;
  final String? email;
  final String? name;
  final String? phone;
  final String? address;
  final String? imageUrl;
  final String? accountId;
  final int? roleId;
  final String? roleName;
  final String? roleCode;
  final bool? status;
  final String? branchName;
  final String? merchantName;
  final String? beaconUuid;
  final int? merchantId;

  factory UserInfo.empty() => UserInfo(id: 0);

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: jsonInt(json['id']) ?? 0,
      email: jsonStr(json['email']),
      name: jsonStr(json['name']),
      phone: jsonStr(json['phone']),
      address: jsonStr(json['address']),
      imageUrl: jsonStr(json['imageUrl']),
      accountId: jsonStr(json['accountId']),
      roleId: jsonInt(json['roleId']),
      roleName: jsonStr(json['roleName']),
      roleCode: jsonStr(json['roleCode']),
      status: jsonBool(json['status']),
      branchName: jsonStr(json['branchName']),
      merchantName: jsonStr(json['merchantName']),
      beaconUuid: jsonStr(json['beaconUuid']),
      merchantId: jsonInt(json['merchantId']),
    );
  }
}
