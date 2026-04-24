import 'package:flutter/foundation.dart';

@immutable
class StockCount {
  const StockCount({
    required this.id,
    required this.name,
    required this.status,
    required this.outletId,
    required this.createdBy,
    required this.plannedDate,
    this.startedAt,
    this.completedAt,
    this.notes,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String status;
  final String outletId;
  final String createdBy;
  final String plannedDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final List<StockCountItem> items;
  final DateTime createdAt;

  factory StockCount.fromJson(Map<String, dynamic> json) => StockCount(
        id: json['id'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        outletId: json['outlet_id'] as String,
        createdBy: json['created_by'] as String,
        plannedDate: json['planned_date'] as String,
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        notes: json['notes'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) =>
                    StockCountItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

@immutable
class StockCountItem {
  const StockCountItem({
    required this.id,
    required this.stockCountId,
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantSize,
    this.sku,
    required this.frozenQty,
    this.actualQty,
    this.difference,
  });

  final String id;
  final String stockCountId;
  final String productId;
  final String variantId;
  final String productName;
  final String variantSize;
  final String? sku;
  final int frozenQty;
  final int? actualQty;
  final int? difference;

  StockCountItem copyWithActualQty(int qty) => StockCountItem(
        id: id,
        stockCountId: stockCountId,
        productId: productId,
        variantId: variantId,
        productName: productName,
        variantSize: variantSize,
        sku: sku,
        frozenQty: frozenQty,
        actualQty: qty,
        difference: qty - frozenQty,
      );

  factory StockCountItem.fromJson(Map<String, dynamic> json) => StockCountItem(
        id: json['id'] as String,
        stockCountId: json['stock_count_id'] as String,
        productId: json['product_id'] as String,
        variantId: json['variant_id'] as String,
        productName: json['product_name'] as String,
        variantSize: json['variant_size'] as String,
        sku: json['sku'] as String?,
        frozenQty: (json['frozen_qty'] as num?)?.toInt() ?? 0,
        actualQty: (json['actual_qty'] as num?)?.toInt(),
        difference: (json['difference'] as num?)?.toInt(),
      );
}
