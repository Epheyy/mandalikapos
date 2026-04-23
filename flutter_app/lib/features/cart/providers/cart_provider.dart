import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../../products/models/product.dart';

// The cart state — a list of cart items
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  // Add or increase quantity of a variant in the cart
  void addItem(Product product, ProductVariant variant, int quantity) {
    if (quantity <= 0) return;

    final existingIndex = state.indexWhere(
      (item) => item.productId == product.id && item.variantId == variant.id,
    );

    if (existingIndex >= 0) {
      // Already in cart — increase quantity
      final updated = List<CartItem>.from(state);
      final existing = updated[existingIndex];
      final newQty = existing.quantity + quantity;
      // Don't exceed available stock
      updated[existingIndex] = existing.copyWith(
        quantity: newQty > variant.stock ? variant.stock : newQty,
      );
      state = updated;
    } else {
      // New item
      state = [...state, CartItem.fromVariant(product, variant, quantity)];
    }
  }

  // Change quantity directly (from cart item row +/- buttons)
  void updateQuantity(String variantId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(variantId);
      return;
    }
    state = state.map((item) {
      if (item.variantId == variantId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();
  }

  void removeItem(String variantId) {
    state = state.where((item) => item.variantId != variantId).toList();
  }

  void clearCart() {
    state = [];
  }
}

// Computed cart totals — derived from cart state automatically
final cartTotalsProvider = Provider((ref) {
  final items = ref.watch(cartProvider);
  final subtotal = items.fold(0, (sum, item) => sum + item.subtotal);
  return CartTotals(
    subtotal: subtotal,
    itemCount: items.fold(0, (sum, item) => sum + item.quantity),
  );
});

class CartTotals {
  final int subtotal;
  final int itemCount;

  const CartTotals({required this.subtotal, required this.itemCount});
}