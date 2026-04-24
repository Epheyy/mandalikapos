import 'package:flutter/foundation.dart';

@immutable
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.points,
    required this.totalSpent,
    required this.visitCount,
    this.lastVisit,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final int points;
  final int totalSpent;
  final int visitCount;
  final DateTime? lastVisit;
  final DateTime createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        totalSpent: (json['total_spent'] as num?)?.toInt() ?? 0,
        visitCount: (json['visit_count'] as num?)?.toInt() ?? 0,
        lastVisit: json['last_visit'] != null
            ? DateTime.parse(json['last_visit'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
      };
}
