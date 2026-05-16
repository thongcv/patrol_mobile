import '../http/api_response.dart';

class Menu {
  Menu({
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
  final List<Menu> children;

  factory Menu.fromJson(Map<String, dynamic> json) {
    final nested = json['menus'];
    final childList = nested is List ? nested : const <dynamic>[];

    return Menu(
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
          .map(Menu.fromJson)
          .toList(),
    );
  }
}
