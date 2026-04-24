import 'package:flutter/foundation.dart';

@immutable
class Shift {
  const Shift({
    required this.id,
    required this.outletId,
    this.outletName,
    required this.cashierId,
    required this.cashierName,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.startingCash,
    this.closingCash,
    required this.totalSales,
    required this.totalOrders,
    required this.totalRefunds,
    required this.cashSales,
    required this.cardSales,
    required this.transferSales,
    required this.qrisSales,
  });

  final String id;
  final String outletId;
  final String? outletName;
  final String cashierId;
  final String cashierName;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int startingCash;
  final int? closingCash;
  final int totalSales;
  final int totalOrders;
  final int totalRefunds;
  final int cashSales;
  final int cardSales;
  final int transferSales;
  final int qrisSales;

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: json['id'] as String,
        outletId: json['outlet_id'] as String,
        outletName: json['outlet_name'] as String?,
        cashierId: json['cashier_id'] as String,
        cashierName: json['cashier_name'] as String,
        status: json['status'] as String,
        openedAt: DateTime.parse(json['opened_at'] as String),
        closedAt: json['closed_at'] != null
            ? DateTime.parse(json['closed_at'] as String)
            : null,
        startingCash: (json['starting_cash'] as num?)?.toInt() ?? 0,
        closingCash: (json['closing_cash'] as num?)?.toInt(),
        totalSales: (json['total_sales'] as num?)?.toInt() ?? 0,
        totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
        totalRefunds: (json['total_refunds'] as num?)?.toInt() ?? 0,
        cashSales: (json['cash_sales'] as num?)?.toInt() ?? 0,
        cardSales: (json['card_sales'] as num?)?.toInt() ?? 0,
        transferSales: (json['transfer_sales'] as num?)?.toInt() ?? 0,
        qrisSales: (json['qris_sales'] as num?)?.toInt() ?? 0,
      );
}
