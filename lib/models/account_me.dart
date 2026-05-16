import '../http/api_response.dart';
import 'manager_info.dart';
import 'menu.dart';
import 'user_info.dart';

class AccountMe {
  AccountMe({
    this.managerInfo,
    required this.userInfo,
    required this.menus,
  });

  final ManagerInfo? managerInfo;
  final UserInfo userInfo;
  final List<Menu> menus;

  factory AccountMe.fromJson(Map<String, dynamic> json) {
    final mi = jsonMapCoerce(json['managerInfo']);
    final ui = jsonMapCoerce(json['userInfo']);
    final rawMenus = json['menus'];
    final menuList = rawMenus is List ? rawMenus : const <dynamic>[];

    return AccountMe(
      managerInfo: mi != null ? ManagerInfo.fromJson(mi) : null,
      userInfo: ui != null ? UserInfo.fromJson(ui) : UserInfo.empty(),
      menus: menuList
          .map(jsonMapCoerce)
          .whereType<Map<String, dynamic>>()
          .map(Menu.fromJson)
          .toList(),
    );
  }
}
