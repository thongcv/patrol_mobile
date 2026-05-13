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
    final mi = json['managerInfo'];
    final ui = json['userInfo'];
    final rawMenus = json['menus'] as List<dynamic>? ?? [];
    return AccountMeDto(
      managerInfo: mi is Map<String, dynamic>
          ? ManagerInfoDto.fromJson(mi)
          : null,
      userInfo: ui is Map<String, dynamic>
          ? UserInfoDto.fromJson(ui)
          : UserInfoDto.empty(),
      menus: rawMenus
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
      accountId: json['accountId'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      accountId: json['accountId'] as String?,
      roleId: (json['roleId'] as num?)?.toInt(),
      roleName: json['roleName'] as String?,
      roleCode: json['roleCode'] as String?,
      status: json['status'] as bool?,
      branchName: json['branchName'] as String?,
      merchantName: json['merchantName'] as String?,
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
    final nested = json['menus'] as List<dynamic>? ?? [];
    return MenuDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentId: (json['parentId'] as num?)?.toInt(),
      icon: json['icon'] as String?,
      name: json['name'] as String?,
      link: json['link'] as String?,
      ordered: (json['ordered'] as num?)?.toInt(),
      servYn: json['servYn'] as bool?,
      roleId: (json['roleId'] as num?)?.toInt(),
      children: nested
          .whereType<Map<String, dynamic>>()
          .map(MenuDto.fromJson)
          .toList(),
    );
  }
}
