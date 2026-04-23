class CreateOrderRequest {
  final List<OrderItemRequest> items;
  final int subtotal;
  final int discountAmount;
  final int taxAmount;
  final int total;
  final String paymentMethod;
  final int amountPaid;
  final int changeAmount;
  final String? customerId;
  final String? notes;
  final String outletId;

  CreateOrderRequest({
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    required this.changeAmount,
    this.customerId,
    this.notes,
    required this.outletId,
  });

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'tax_amount': taxAmount,
        'total': total,
        'payment_method': paymentMethod,
        'amount_paid': amountPaid,
        'change_amount': changeAmount,
        if (customerId != null) 'customer_id': customerId,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'outlet_id': outletId,
      };
}

class OrderItemRequest {
  final String productId;
  final String variantId;
  final String productName;
  final String variantSize;
  final int price;
  final int quantity;
  final int subtotal;

  OrderItemRequest({
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantSize,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'variant_id': variantId,
        'product_name': productName,
        'variant_size': variantSize,
        'price': price,
        'quantity': quantity,
        'subtotal': subtotal,
      };
}