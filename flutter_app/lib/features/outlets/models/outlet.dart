import 'package:flutter/foundation.dart';

@immutable
class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
