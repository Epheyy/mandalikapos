import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../products/models/product.dart';
import '../../products/providers/products_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

// Currency formatter for IDR

class CashierScreen extends ConsumerWidget {
  const CashierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 26,
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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Keluar?'),
                  content: const Text('Anda akan keluar dari aplikasi.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authServiceProvider).signOut();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────
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

          // ── Category Filter ────────────────────────────────
          categoriesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
            data: (categories) => SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

          // ── Product Grid ───────────────────────────────────
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
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _ProductCard(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Chip ──────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGold : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Product Card ───────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: product.isOutOfStock
            ? null
            : () {
                // TODO Phase 3: show variant selector and add to cart
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} — cart coming in Phase 3!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _PlaceholderImage(),
                        )
                      : const _PlaceholderImage(),

                  // Out of stock overlay
                  if (product.isOutOfStock)
                    Container(
                      color: Colors.white.withAlpha(179),
                      child: const Center(
                        child: Text(
                          'Habis',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                  // Low stock badge
                  if (product.totalStock <= 5 && !product.isOutOfStock)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Stok ${product.totalStock}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warning,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.variants.length} varian',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
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
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.inventory_2_outlined,
            size: 32, color: AppTheme.textMuted),
      );
}

// ── Skeleton loader while products are loading ─────────────────────
class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Tidak ada produk',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
          ],
        ),
      );
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
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
}