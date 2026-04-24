import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/promotions/models/promotion.dart';
import 'package:mandalika_pos/features/promotions/providers/promotions_provider.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promosi'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Promosi'), Tab(text: 'Kode Diskon')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(promotionsProvider);
              ref.invalidate(discountCodesProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PromotionsList(),
          _DiscountCodesList(),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (ctx, _) => FloatingActionButton.extended(
          onPressed: _tabs.index == 0
              ? () => _showPromotionForm(context)
              : () => _showDiscountCodeForm(context),
          icon: const Icon(Icons.add),
          label: Text(_tabs.index == 0 ? 'Tambah Promosi' : 'Tambah Kode'),
        ),
      ),
    );
  }

  void _showPromotionForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _PromotionFormDialog(
        onSaved: () => ref.invalidate(promotionsProvider),
      ),
    );
  }

  void _showDiscountCodeForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DiscountCodeFormDialog(
        onSaved: () => ref.invalidate(discountCodesProvider),
      ),
    );
  }
}

class _PromotionsList extends ConsumerWidget {
  const _PromotionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promoAsync = ref.watch(promotionsProvider);

    return promoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (promos) => promos.isEmpty
          ? const Center(child: Text('Belum ada promosi'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: promos.length,
              itemBuilder: (ctx, i) => _PromotionTile(
                promo: promos[i],
                onMutated: () => ref.invalidate(promotionsProvider),
              ),
            ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  const _PromotionTile({required this.promo, required this.onMutated});
  final Promotion promo;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    final valueText = promo.type == 'percentage'
        ? '${promo.value}%'
        : promo.type == 'fixed'
            ? _idr.format(promo.value)
            : 'BOGO';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
          child: const Icon(Icons.local_offer, color: Color(0xFF6366F1)),
        ),
        title: Text(promo.name),
        subtitle: Text('${_typeLabel(promo.type)} • $valueText'
            '${promo.minPurchase > 0 ? ' • Min. ${_idr.format(promo.minPurchase)}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActiveBadge(isActive: promo.isActive),
            Consumer(
              builder: (ctx, ref, _) => IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(ctx, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    return switch (type) {
      'percentage' => 'Persentase',
      'fixed' => 'Nominal',
      'bogo' => 'BOGO',
      _ => type,
    };
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Promosi'),
        content: Text('Yakin ingin menghapus "${promo.name}"?'),
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
      await ref.read(apiClientProvider).delete('/admin/promotions/${promo.id}');
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

class _DiscountCodesList extends ConsumerWidget {
  const _DiscountCodesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codesAsync = ref.watch(discountCodesProvider);

    return codesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (codes) => codes.isEmpty
          ? const Center(child: Text('Belum ada kode diskon'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: codes.length,
              itemBuilder: (ctx, i) => _DiscountCodeTile(
                code: codes[i],
                onMutated: () => ref.invalidate(discountCodesProvider),
              ),
            ),
    );
  }
}

class _DiscountCodeTile extends StatelessWidget {
  const _DiscountCodeTile({required this.code, required this.onMutated});
  final DiscountCode code;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    final valueText = code.type == 'percentage'
        ? '${code.value}%'
        : _idr.format(code.value);
    final usageText = code.usageLimit != null
        ? '${code.usageCount}/${code.usageLimit}'
        : '${code.usageCount}x';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(code.code,
              style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ),
        title: Text('$valueText diskon'),
        subtitle: Text('Digunakan: $usageText'
            '${code.minPurchase > 0 ? ' • Min. ${_idr.format(code.minPurchase)}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActiveBadge(isActive: code.isActive),
            Consumer(
              builder: (ctx, ref, _) => IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(ctx, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kode Diskon'),
        content: Text('Yakin ingin menghapus kode "${code.code}"?'),
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
      await ref.read(apiClientProvider).delete('/admin/discount-codes/${code.id}');
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(isActive ? 'Aktif' : 'Nonaktif',
          style: TextStyle(
              color: isActive ? Colors.green : Colors.grey, fontSize: 11)),
    );
  }
}

class _PromotionFormDialog extends ConsumerStatefulWidget {
  const _PromotionFormDialog({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_PromotionFormDialog> createState() => _PromotionFormDialogState();
}

class _PromotionFormDialogState extends ConsumerState<_PromotionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _minPurchase = TextEditingController(text: '0');
  String _type = 'percentage';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _minPurchase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Promosi'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama Promosi'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipe'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Persentase (%)')),
                DropdownMenuItem(value: 'fixed', child: Text('Nominal (Rp)')),
                DropdownMenuItem(value: 'bogo', child: Text('Buy One Get One')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              decoration: InputDecoration(
                labelText: _type == 'percentage' ? 'Nilai (%)' : 'Nilai (Rp)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minPurchase,
              decoration: const InputDecoration(labelText: 'Minimum Pembelian (Rp)'),
              keyboardType: TextInputType.number,
            ),
          ],
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
      await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/admin/promotions',
        data: {
          'name': _name.text,
          'type': _type,
          'value': int.parse(_value.text),
          'min_purchase': int.tryParse(_minPurchase.text) ?? 0,
          'is_active': true,
          'combinable': false,
          'active_days': [0, 1, 2, 3, 4, 5, 6],
          'product_ids': <String>[],
        },
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DiscountCodeFormDialog extends ConsumerStatefulWidget {
  const _DiscountCodeFormDialog({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_DiscountCodeFormDialog> createState() => _DiscountCodeFormDialogState();
}

class _DiscountCodeFormDialogState extends ConsumerState<_DiscountCodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minPurchase = TextEditingController(text: '0');
  final _usageLimit = TextEditingController();
  String _type = 'percentage';
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minPurchase.dispose();
    _usageLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Kode Diskon'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Kode'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipe'),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text('Persentase (%)')),
                DropdownMenuItem(value: 'fixed', child: Text('Nominal (Rp)')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              decoration: InputDecoration(
                labelText: _type == 'percentage' ? 'Nilai (%)' : 'Nilai (Rp)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minPurchase,
              decoration: const InputDecoration(labelText: 'Minimum Pembelian (Rp)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usageLimit,
              decoration: const InputDecoration(labelText: 'Batas Penggunaan (kosongkan = tak terbatas)'),
              keyboardType: TextInputType.number,
            ),
          ],
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
      await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/admin/discount-codes',
        data: {
          'code': _code.text.toUpperCase(),
          'type': _type,
          'value': int.parse(_value.text),
          'min_purchase': int.tryParse(_minPurchase.text) ?? 0,
          if (_usageLimit.text.isNotEmpty) 'usage_limit': int.parse(_usageLimit.text),
          'is_active': true,
        },
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
