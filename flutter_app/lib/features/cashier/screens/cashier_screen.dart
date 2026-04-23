import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../../cart/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/variant_selector.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/screens/printer_settings_screen.dart';
import '../../../core/bluetooth/printer_service.dart';
import '../../../shared/theme/app_theme.dart';
import 'checkout_screen.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class CashierScreen extends ConsumerWidget {
  const CashierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final cartTotals = ref.watch(cartTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 32, height: 26,
              child: Image.network(
                'https://mandalikaperfume.co.id/wp-content/uploads/2025/02/GOLD-Tanpa-Text-Bawah.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Mandalika POS'),
          ],
        ),
        actions: [
            Consumer(builder: (context, ref, _) {
              final status = ref.watch(printerStatusProvider);
              return IconButton(
                icon: Icon(
                  Icons.print_rounded,
                  color: status == PrinterStatus.connected
                      ? AppTheme.success
                      : AppTheme.textMuted,
                ),
                tooltip: 'Pengaturan Printer',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrinterSettingsScreen()),
                  ),
                );
              }),
          // Cart button with item count badge
          if (cartTotals.itemCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_rounded),
                  onPressed: () => _showCart(context, ref),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartTotals.itemCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Category chips
          categoriesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
            data: (categories) => SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CategoryChip(
                      label: 'Semua',
                      isSelected: selectedCategory == null,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = null,
                    );
                  }
                  final cat = categories[index - 1];
                  return _CategoryChip(
                    label: cat.name,
                    isSelected: selectedCategory == cat.id,
                    onTap: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .state = cat.id,
                  );
                },
              ),
            ),
          ),

          // Product grid
          Expanded(
            child: productsAsync.when(
              loading: () => const _ProductGridSkeleton(),
              error: (error, _) => _ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(productsProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return const _EmptyProducts();
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _ProductCard(
                    product: products[index],
                    onTap: () => showVariantSelector(
                        context, ref, products[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Checkout bottom bar — appears when cart has items
      bottomNavigationBar: cartTotals.itemCount > 0
          ? _CheckoutBar(
              itemCount: cartTotals.itemCount,
              total: cartTotals.subtotal,
              onCheckout: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CheckoutScreen()),
              ),
            )
          : null,
    );
  }

  void _showCart(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CartSheet(),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari aplikasi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(authServiceProvider).signOut();
    }
  }
}

// ── Cart Bottom Sheet ──────────────────────────────────────────────
class _CartSheet extends ConsumerWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text('Keranjang (${totals.itemCount})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clearCart();
                    Navigator.pop(context);
                  },
                  child: const Text('Kosongkan',
                      style: TextStyle(color: AppTheme.error)),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (_, i) => _CartItemRow(
                cartItem: items[i],
                onIncrease: () => ref
                    .read(cartProvider.notifier)
                    .updateQuantity(items[i].variantId, items[i].quantity + 1),
                onDecrease: () => ref
                    .read(cartProvider.notifier)
                    .updateQuantity(items[i].variantId, items[i].quantity - 1),
                onRemove: () => ref
                    .read(cartProvider.notifier)
                    .removeItem(items[i].variantId),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.borderGray)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    Text(_idr.format(totals.subtotal),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CheckoutScreen()),
                      );
                    },
                    child: Text('Bayar ${_idr.format(totals.subtotal)}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final cartItem;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.cartItem,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cartItem.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${cartItem.variantSize} · ${_idr.format(cartItem.price)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                  onPressed: onDecrease,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  iconSize: 20,
                  color: AppTheme.textSecondary),
              Text('${cartItem.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(
                  onPressed: onIncrease,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  iconSize: 20,
                  color: AppTheme.primaryGold),
              Text(_idr.format(cartItem.subtotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Checkout Bottom Bar ────────────────────────────────────────────
class _CheckoutBar extends StatelessWidget {
  final int itemCount;
  final int total;
  final VoidCallback onCheckout;

  const _CheckoutBar({
    required this.itemCount,
    required this.total,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onCheckout,
        child: Text('Bayar $itemCount item · ${_idr.format(total)}'),
      ),
    );
  }
}

// ── Product Card ───────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product.isOutOfStock ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl != null
                      ? Image.network(product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _PlaceholderImage())
                      : const _PlaceholderImage(),
                  if (product.isOutOfStock)
                    Container(
                      color: Colors.white.withAlpha(179),
                      child: const Center(
                          child: Text('Habis',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textSecondary,
                                  fontSize: 12))),
                    ),
                  if (product.totalStock <= 5 && !product.isOutOfStock)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Stok ${product.totalStock}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warning)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${product.variants.length} varian',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();
  @override
  Widget build(BuildContext context) => Container(
      color: AppTheme.backgroundGray,
      child: const Icon(Icons.inventory_2_outlined,
          size: 32, color: AppTheme.textMuted));
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGold
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      );
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.72,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Expanded(
              child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16)))),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 10, color: const Color(0xFFE5E7EB)),
                    const SizedBox(height: 4),
                    Container(
                        height: 10,
                        width: 60,
                        color: const Color(0xFFE5E7EB)),
                  ]),
            ),
          ]),
        ),
      );
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();
  @override
  Widget build(BuildContext context) => const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined,
            size: 48, color: AppTheme.textMuted),
        SizedBox(height: 12),
        Text('Tidak ada produk',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
      ]));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Coba Lagi')),
              ]),
        ),
      );
}