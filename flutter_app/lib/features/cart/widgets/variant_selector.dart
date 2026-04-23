import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../products/models/product.dart';
import '../providers/cart_provider.dart';
import '../../../shared/theme/app_theme.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

// Shows a bottom sheet for selecting variant quantities
// Called when a product card is tapped
Future<void> showVariantSelector(
  BuildContext context,
  WidgetRef ref,
  Product product,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VariantSelectorSheet(product: product, ref: ref),
  );
}

class VariantSelectorSheet extends ConsumerStatefulWidget {
  final Product product;
  final WidgetRef ref;

  const VariantSelectorSheet({
    super.key,
    required this.product,
    required this.ref,
  });

  @override
  ConsumerState<VariantSelectorSheet> createState() =>
      _VariantSelectorSheetState();
}

class _VariantSelectorSheetState extends ConsumerState<VariantSelectorSheet> {
  // Track selected quantities per variant
  late Map<String, int> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = {
      for (final v in widget.product.variants) v.id: 0,
    };
  }

  int get _totalSelected =>
      _quantities.values.fold(0, (sum, qty) => sum + qty);

  int get _totalPrice {
    int total = 0;
    for (final variant in widget.product.variants) {
      total += variant.price * (_quantities[variant.id] ?? 0);
    }
    return total;
  }

  void _updateQty(String variantId, int delta, int maxStock) {
    setState(() {
      final current = _quantities[variantId] ?? 0;
      final newQty = (current + delta).clamp(0, maxStock);
      _quantities[variantId] = newQty;
    });
  }

  void _addToCart() {
    for (final variant in widget.product.variants) {
      final qty = _quantities[variant.id] ?? 0;
      if (qty > 0) {
        ref.read(cartProvider.notifier).addItem(widget.product, variant, qty);
      }
    }
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_totalSelected item ditambahkan ke keranjang'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                // Product image
                if (widget.product.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.product.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppTheme.backgroundGray,
                        child: const Icon(Icons.inventory_2_outlined,
                            color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppTheme.textPrimary)),
                      Text(widget.product.brand,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Variant list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: widget.product.variants.map((variant) {
                final qty = _quantities[variant.id] ?? 0;
                final isOut = variant.isOutOfStock;

                return Opacity(
                  opacity: isOut ? 0.5 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: qty > 0
                          ? AppTheme.primaryGoldLight
                          : AppTheme.backgroundGray,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: qty > 0
                            ? AppTheme.primaryGold
                            : AppTheme.borderGray,
                        width: qty > 0 ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Variant info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                variant.size,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: qty > 0
                                      ? AppTheme.primaryGoldDark
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _idr.format(variant.price),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: qty > 0
                                      ? AppTheme.primaryGold
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                isOut
                                    ? 'Stok habis'
                                    : 'Stok: ${variant.stock}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOut
                                      ? AppTheme.error
                                      : variant.isLowStock
                                          ? AppTheme.warning
                                          : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quantity controls
                        if (!isOut) ...[
                          _QtyButton(
                            icon: Icons.remove_rounded,
                            onTap: qty > 0
                                ? () => _updateQty(variant.id, -1, variant.stock)
                                : null,
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: qty > 0
                                    ? AppTheme.primaryGoldDark
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          _QtyButton(
                            icon: Icons.add_rounded,
                            onTap: qty < variant.stock
                                ? () => _updateQty(variant.id, 1, variant.stock)
                                : null,
                            filled: true,
                          ),
                        ] else
                          const Text('Habis',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Add to cart button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _totalSelected > 0 ? _addToCart : null,
                child: Text(
                  _totalSelected == 0
                      ? 'Pilih varian'
                      : 'Tambah $_totalSelected item · ${_idr.format(_totalPrice)}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  const _QtyButton({required this.icon, this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: filled
              ? (onTap != null ? AppTheme.primaryGold : AppTheme.borderGray)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? AppTheme.primaryGold : AppTheme.borderGray,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled
              ? Colors.white
              : (onTap != null ? AppTheme.primaryGold : AppTheme.textMuted),
        ),
      ),
    );
  }
}