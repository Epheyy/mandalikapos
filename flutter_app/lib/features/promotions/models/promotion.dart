import 'package:flutter/foundation.dart';

@immutable
class Promotion {
  const Promotion({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.value,
    required this.minPurchase,
    required this.combinable,
    this.activeFromHour,
    this.activeToHour,
    required this.activeDays,
    required this.productIds,
    required this.isActive,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String type;
  final int value;
  final int minPurchase;
  final bool combinable;
  final String? activeFromHour;
  final String? activeToHour;
  final List<int> activeDays;
  final List<String> productIds;
  final bool isActive;
  final String? startDate;
  final String? endDate;
  final DateTime createdAt;

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        type: json['type'] as String,
        value: (json['value'] as num?)?.toInt() ?? 0,
        minPurchase: (json['min_purchase'] as num?)?.toInt() ?? 0,
        combinable: (json['combinable'] as bool?) ?? false,
        activeFromHour: json['active_from_hour'] as String?,
        activeToHour: json['active_to_hour'] as String?,
        activeDays: (json['active_days'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            [],
        productIds: (json['product_ids'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        isActive: (json['is_active'] as bool?) ?? true,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

@immutable
class DiscountCode {
  const DiscountCode({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.minPurchase,
    this.usageLimit,
    required this.usageCount,
    required this.isActive,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String type;
  final int value;
  final int minPurchase;
  final int? usageLimit;
  final int usageCount;
  final bool isActive;
  final String? startDate;
  final String? endDate;
  final DateTime createdAt;

  factory DiscountCode.fromJson(Map<String, dynamic> json) => DiscountCode(
        id: json['id'] as String,
        code: json['code'] as String,
        type: json['type'] as String,
        value: (json['value'] as num?)?.toInt() ?? 0,
        minPurchase: (json['min_purchase'] as num?)?.toInt() ?? 0,
        usageLimit: (json['usage_limit'] as num?)?.toInt(),
        usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
        isActive: (json['is_active'] as bool?) ?? true,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

@immutable
class DiscountValidationResult {
  const DiscountValidationResult({
    required this.valid,
    required this.discountAmount,
    this.message,
  });

  final bool valid;
  final int discountAmount;
  final String? message;

  factory DiscountValidationResult.fromJson(Map<String, dynamic> json) =>
      DiscountValidationResult(
        valid: (json['valid'] as bool?) ?? false,
        discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
        message: json['message'] as String?,
      );
}
