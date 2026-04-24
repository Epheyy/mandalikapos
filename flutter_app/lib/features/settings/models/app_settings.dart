import 'package:flutter/foundation.dart';

@immutable
class PaymentMethodConfig {
  const PaymentMethodConfig({
    required this.id,
    required this.label,
    required this.isEnabled,
  });

  final String id;
  final String label;
  final bool isEnabled;

  factory PaymentMethodConfig.fromJson(Map<String, dynamic> json) =>
      PaymentMethodConfig(
        id: json['id'] as String,
        label: json['label'] as String,
        isEnabled: (json['is_enabled'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'is_enabled': isEnabled,
      };

  PaymentMethodConfig copyWith({bool? isEnabled}) => PaymentMethodConfig(
        id: id,
        label: label,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}

@immutable
class ReceiptSettings {
  const ReceiptSettings({
    required this.headerText,
    required this.footerText,
    required this.showTax,
    required this.showCashier,
    required this.copies,
    required this.autoPrint,
    required this.showOrderNumber,
    required this.showCustomerName,
    required this.showDiscount,
    required this.showSubtotal,
    required this.showChange,
  });

  final String headerText;
  final String footerText;
  final bool showTax;
  final bool showCashier;
  final int copies;
  final bool autoPrint;
  final bool showOrderNumber;
  final bool showCustomerName;
  final bool showDiscount;
  final bool showSubtotal;
  final bool showChange;

  factory ReceiptSettings.fromJson(Map<String, dynamic> json) =>
      ReceiptSettings(
        headerText: json['header_text'] as String? ?? 'Mandalika Perfume',
        footerText:
            json['footer_text'] as String? ?? 'Terima kasih telah berbelanja!',
        showTax: (json['show_tax'] as bool?) ?? false,
        showCashier: (json['show_cashier'] as bool?) ?? true,
        copies: (json['copies'] as num?)?.toInt() ?? 1,
        autoPrint: (json['auto_print'] as bool?) ?? false,
        showOrderNumber: (json['show_order_number'] as bool?) ?? true,
        showCustomerName: (json['show_customer_name'] as bool?) ?? true,
        showDiscount: (json['show_discount'] as bool?) ?? true,
        showSubtotal: (json['show_subtotal'] as bool?) ?? true,
        showChange: (json['show_change'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'header_text': headerText,
        'footer_text': footerText,
        'show_tax': showTax,
        'show_cashier': showCashier,
        'copies': copies,
        'auto_print': autoPrint,
        'show_order_number': showOrderNumber,
        'show_customer_name': showCustomerName,
        'show_discount': showDiscount,
        'show_subtotal': showSubtotal,
        'show_change': showChange,
      };
}

@immutable
class AppSettings {
  const AppSettings({
    required this.taxEnabled,
    required this.taxRate,
    required this.roundingEnabled,
    required this.roundingType,
    required this.paymentMethods,
    required this.receipt,
    required this.autoOpenShift,
  });

  final bool taxEnabled;
  final double taxRate;
  final bool roundingEnabled;
  final String roundingType;
  final List<PaymentMethodConfig> paymentMethods;
  final ReceiptSettings receipt;
  final bool autoOpenShift;

  List<PaymentMethodConfig> get enabledPaymentMethods =>
      paymentMethods.where((m) => m.isEnabled).toList();

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        taxEnabled: (json['tax_enabled'] as bool?) ?? false,
        taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 11.0,
        roundingEnabled: (json['rounding_enabled'] as bool?) ?? false,
        roundingType: json['rounding_type'] as String? ?? 'none',
        paymentMethods: (json['payment_methods'] as List<dynamic>?)
                ?.map((e) =>
                    PaymentMethodConfig.fromJson(e as Map<String, dynamic>))
                .toList() ??
            _defaultPaymentMethods,
        receipt: json['receipt'] != null
            ? ReceiptSettings.fromJson(
                json['receipt'] as Map<String, dynamic>)
            : const ReceiptSettings(
                headerText: 'Mandalika Perfume',
                footerText: 'Terima kasih telah berbelanja!',
                showTax: false,
                showCashier: true,
                copies: 1,
                autoPrint: false,
                showOrderNumber: true,
                showCustomerName: true,
                showDiscount: true,
                showSubtotal: true,
                showChange: true,
              ),
        autoOpenShift: (json['auto_open_shift'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'tax_enabled': taxEnabled,
        'tax_rate': taxRate,
        'rounding_enabled': roundingEnabled,
        'rounding_type': roundingType,
        'payment_methods': paymentMethods.map((m) => m.toJson()).toList(),
        'receipt': receipt.toJson(),
        'auto_open_shift': autoOpenShift,
      };

  static const _defaultPaymentMethods = [
    PaymentMethodConfig(id: 'cash', label: 'Tunai', isEnabled: true),
    PaymentMethodConfig(id: 'card', label: 'Kartu', isEnabled: true),
    PaymentMethodConfig(id: 'transfer', label: 'Transfer', isEnabled: true),
    PaymentMethodConfig(id: 'qris', label: 'QRIS', isEnabled: true),
  ];
}
