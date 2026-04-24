import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/products/models/product.dart';
import 'package:mandalika_pos/features/products/providers/products_provider.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

// Admin products provider (all products, including inactive)
final _adminProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/products');
  final data = response.data ?? [];
  return data
      .map((p) => Product.fromJson(p as Map<String, dynamic>))
      .toList();
});

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_adminProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_adminProductsProvider),
          ),
          FilledButton.icon(
            onPressed: () => _showProductForm(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) => products.isEmpty
            ? const Center(child: Text('Belum ada produk'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (ctx, i) =>
                    _ProductCard(product: products[i], onMutated: () => ref.invalidate(_adminProductsProvider)),
              ),
      ),
    );
  }

  void _showProductForm(BuildContext context, WidgetRef ref, Product? product) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductFormDialog(
        product: product,
        onSaved: () {
          ref.invalidate(_adminProductsProvider);
          ref.invalidate(productsProvider);
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onMutated});
  final Product product;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: product.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(product.imageUrl!,
                    width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48)),
              )
            : const Icon(Icons.inventory_2, size: 48),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${product.brand} • Stok: ${product.totalStock}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (product.isActive ? Colors.green : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(product.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                      color: product.isActive ? Colors.green : Colors.grey,
                      fontSize: 11)),
            ),
            const SizedBox(width: 8),
            Consumer(builder: (ctx, ref, _) => PopupMenuButton<String>(
              onSelected: (v) => _onAction(ctx, ref, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
            )),
          ],
        ),
        children: product.variants.map((v) => ListTile(
          dense: true,
          title: Text(v.size),
          trailing: Text('${_idr.format(v.price)} • Stok: ${v.stock}'),
        )).toList(),
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'edit') {
      showDialog(
        context: context,
        builder: (ctx) => _ProductFormDialog(
          product: product,
          onSaved: onMutated,
        ),
      );
    } else if (action == 'delete') {
      _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin ingin menghapus "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/admin/products/${product.id}');
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

class _ProductFormDialog extends ConsumerStatefulWidget {
  const _ProductFormDialog({this.product, required this.onSaved});
  final Product? product;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _description;
  String? _categoryId;
  bool _isActive = true;
  bool _isFeatured = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _brand = TextEditingController(text: widget.product?.brand ?? '');
    _description = TextEditingController(text: widget.product?.description ?? '');
    _categoryId = widget.product?.categoryId;
    _isActive = widget.product?.isActive ?? true;
    _isFeatured = widget.product?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Text(widget.product == null ? 'Tambah Produk' : 'Edit Produk'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama Produk'),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brand,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                categoriesAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('$e'),
                  data: (cats) => DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Pilih kategori' : null,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Featured'),
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = {
        'name': _name.text,
        'brand': _brand.text,
        'description': _description.text,
        'category_id': _categoryId,
        'is_active': _isActive,
        'is_featured': _isFeatured,
      };
      if (widget.product == null) {
        await api.post<Map<String, dynamic>>('/admin/products', data: body);
      } else {
        await api.put<Map<String, dynamic>>(
            '/admin/products/${widget.product!.id}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
