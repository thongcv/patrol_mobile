import '../http/api_response.dart';

class AccountMeDto {
  AccountMeDto({
    this.managerInfo,
    required this.userInfo,
    required this.menus,
  });

  final ManagerInfoDto? managerInfo;
  final UserInfoDto userInfo;
  final List<MenuDto> menus;

  factory AccountMeDto.fromJson(Map<String, dynamic> json) {
    final mi = jsonMapCoerce(json['managerInfo']);
    final ui = jsonMapCoerce(json['userInfo']);
    final rawMenus = json['menus'];
    final menuList = rawMenus is List ? rawMenus : const <dynamic>[];

    return AccountMeDto(
      managerInfo: mi != null ? ManagerInfoDto.fromJson(mi) : null,
      userInfo: ui != null ? UserInfoDto.fromJson(ui) : UserInfoDto.empty(),
      menus: menuList
          .map(jsonMapCoerce)
          .whereType<Map<String, dynamic>>()
          .map(MenuDto.fromJson)
          .toList(),
    );
  }
}

class ManagerInfoDto {
  ManagerInfoDto({
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

  factory ManagerInfoDto.fromJson(Map<String, dynamic> json) {
    return ManagerInfoDto(
      accountId: jsonStr(json['accountId']),
      name: jsonStr(json['name']),
      email: jsonStr(json['email']),
      phone: jsonStr(json['phone']),
      avatar: jsonStr(json['avatar']),
    );
  }
}

class UserInfoDto {
  UserInfoDto({
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

  factory UserInfoDto.empty() => UserInfoDto(id: 0);

  factory UserInfoDto.fromJson(Map<String, dynamic> json) {
    return UserInfoDto(
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
    );
  }
}

class MenuDto {
  MenuDto({
    required this.id,
    this.parentId,
    this.icon,
    this.name,
    this.link,
    this.ordered,
    this.servYn,
    this.roleId,
    required this.children,
  });

  final int id;
  final int? parentId;
  final String? icon;
  final String? name;
  final String? link;
  final int? ordered;
  final bool? servYn;
  final int? roleId;
  final List<MenuDto> children;

  factory MenuDto.fromJson(Map<String, dynamic> json) {
    final nested = json['menus'];
    final childList = nested is List ? nested : const <dynamic>[];

    return MenuDto(
      id: jsonInt(json['id']) ?? 0,
      parentId: jsonInt(json['parentId']),
      icon: jsonStr(json['icon']),
      name: jsonStr(json['name']),
      link: jsonStr(json['link']),
      ordered: jsonInt(json['ordered']),
      servYn: jsonBool(json['servYn']),
      roleId: jsonInt(json['roleId']),
      children: childList
          .map(jsonMapCoerce)
          .whereType<Map<String, dynamic>>()
          .map(MenuDto.fromJson)
          .toList(),
    );
  }
}
