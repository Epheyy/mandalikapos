import 'package:flutter/foundation.dart';

@immutable
class DashboardStats {
  const DashboardStats({
    required this.todaySales,
    required this.todayOrders,
    required this.todayCustomers,
    required this.weekSales,
    required this.monthSales,
    required this.topProducts,
    required this.salesByDay,
    required this.paymentBreakdown,
  });

  final int todaySales;
  final int todayOrders;
  final int todayCustomers;
  final int weekSales;
  final int monthSales;
  final List<TopProduct> topProducts;
  final List<DaySales> salesByDay;
  final List<PaymentBreakdown> paymentBreakdown;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        todaySales: (json['today_sales'] as num?)?.toInt() ?? 0,
        todayOrders: (json['today_orders'] as num?)?.toInt() ?? 0,
        todayCustomers: (json['today_customers'] as num?)?.toInt() ?? 0,
        weekSales: (json['week_sales'] as num?)?.toInt() ?? 0,
        monthSales: (json['month_sales'] as num?)?.toInt() ?? 0,
        topProducts: (json['top_products'] as List<dynamic>?)
                ?.map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        salesByDay: (json['sales_by_day'] as List<dynamic>?)
                ?.map((e) => DaySales.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        paymentBreakdown: (json['payment_breakdown'] as List<dynamic>?)
                ?.map((e) => PaymentBreakdown.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

@immutable
class TopProduct {
  const TopProduct({
    required this.productName,
    required this.variantSize,
    required this.quantity,
    required this.revenue,
  });

  final String productName;
  final String variantSize;
  final int quantity;
  final int revenue;

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        productName: json['product_name'] as String,
        variantSize: json['variant_size'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class DaySales {
  const DaySales({
    required this.date,
    required this.sales,
    required this.orders,
  });

  final String date;
  final int sales;
  final int orders;

  factory DaySales.fromJson(Map<String, dynamic> json) => DaySales(
        date: json['date'] as String,
        sales: (json['sales'] as num?)?.toInt() ?? 0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class PaymentBreakdown {
  const PaymentBreakdown({
    required this.method,
    required this.amount,
    required this.count,
  });

  final String method;
  final int amount;
  final int count;

  factory PaymentBreakdown.fromJson(Map<String, dynamic> json) =>
      PaymentBreakdown(
        method: json['method'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}
