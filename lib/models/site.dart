import '../http/api_response.dart';

class Site {
  Site({
    required this.id,
    required this.name,
    this.address,
  });

  final int id;
  final String name;
  final String? address;

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: jsonInt(json['id']) ?? 0,
      name: jsonStr(json['name']) ?? '',
      address: jsonStr(json['address']),
    );
  }
}
