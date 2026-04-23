import 'package:flutter/foundation.dart';
import '../../products/models/product.dart';

@immutable
class CartItem {
  final String productId;
  final String variantId;
  final String productName;
  final String variantSize;
  final int price;
  final int quantity;

  const CartItem({
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantSize,
    required this.price,
    required this.quantity,
  });

  int get subtotal => price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        productId: productId,
        variantId: variantId,
        productName: productName,
        variantSize: variantSize,
        price: price,
        quantity: quantity ?? this.quantity,
      );

  static CartItem fromVariant(Product product, ProductVariant variant, int qty) =>
      CartItem(
        productId: product.id,
        variantId: variant.id,
        productName: product.name,
        variantSize: variant.size,
        price: variant.price,
        quantity: qty,
      );
}