import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/stock_count/models/stock_count.dart';
import 'package:mandalika_pos/features/stock_count/providers/stock_count_provider.dart';

class StockCountScreen extends ConsumerWidget {
  const StockCountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(stockCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Opname'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(stockCountsProvider),
          ),
        ],
      ),
      body: countsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (counts) => counts.isEmpty
            ? const Center(child: Text('Belum ada sesi stok opname'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: counts.length,
                itemBuilder: (ctx, i) => _StockCountCard(
                  count: counts[i],
                  onMutated: () => ref.invalidate(stockCountsProvider),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Buat Sesi'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _CreateStockCountDialog(
        onCreated: () => ref.invalidate(stockCountsProvider),
      ),
    );
  }
}

class _StockCountCard extends StatelessWidget {
  const _StockCountCard({required this.count, required this.onMutated});
  final StockCount count;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (count.status) {
      'draft' => (Colors.grey, 'Draft'),
      'in_progress' => (Colors.blue, 'Berlangsung'),
      'completed' => (Colors.green, 'Selesai'),
      _ => (Colors.grey, count.status),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.assignment, color: color),
        ),
        title: Text(count.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tanggal: ${count.plannedDate}'),
            Text('${count.items.length} produk'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(label, style: TextStyle(color: color, fontSize: 11)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _openDetail(context),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _openDetail(context),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StockCountDetailScreen(countId: count.id),
      ),
    );
  }
}

class _StockCountDetailScreen extends ConsumerWidget {
  const _StockCountDetailScreen({required this.countId});
  final String countId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(stockCountDetailProvider(countId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Stok Opname'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(stockCountDetailProvider(countId)),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (count) => _StockCountDetailView(
          count: count,
          onMutated: () => ref.invalidate(stockCountDetailProvider(countId)),
        ),
      ),
    );
  }
}

class _StockCountDetailView extends ConsumerWidget {
  const _StockCountDetailView({required this.count, required this.onMutated});
  final StockCount count;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = count.status != 'completed';

    return Column(
      children: [
        _DetailHeader(count: count, onMutated: onMutated),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: count.items.length,
            itemBuilder: (ctx, i) {
              final item = count.items[i];
              return _StockCountItemTile(
                item: item,
                canEdit: canEdit,
                onUpdated: (qty) => _updateItem(context, ref, item, qty),
              );
            },
          ),
        ),
        if (canEdit && count.status == 'in_progress')
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _completeCount(context, ref),
                icon: const Icon(Icons.check),
                label: const Text('Selesaikan Opname'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _updateItem(BuildContext context, WidgetRef ref, StockCountItem item, int qty) async {
    try {
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
        '/admin/stock-counts/${count.id}/items/${item.id}',
        data: {'actual_qty': qty},
      );
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _completeCount(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selesaikan Opname'),
        content: const Text('Yakin ingin menyelesaikan opname ini? Status tidak bisa diubah setelah selesai.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesai')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
        '/admin/stock-counts/${count.id}/status',
        data: {'status': 'completed'},
      );
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.count, required this.onMutated});
  final StockCount count;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    final discrepancies = count.items.where((i) => i.difference != null && i.difference != 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(count.name, style: Theme.of(context).textTheme.titleMedium),
                Text('Tanggal: ${count.plannedDate}'),
                if (count.notes != null) Text('Catatan: ${count.notes}'),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${count.items.length} item'),
              Text('$discrepancies selisih',
                  style: TextStyle(
                      color: discrepancies > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockCountItemTile extends StatelessWidget {
  const _StockCountItemTile({
    required this.item,
    required this.canEdit,
    required this.onUpdated,
  });

  final StockCountItem item;
  final bool canEdit;
  final void Function(int) onUpdated;

  @override
  Widget build(BuildContext context) {
    final diff = item.difference;
    final diffColor = diff == null
        ? Colors.grey
        : diff == 0
            ? Colors.green
            : diff > 0
                ? Colors.blue
                : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text('${item.productName} (${item.variantSize})'),
        subtitle: item.sku != null ? Text('SKU: ${item.sku}') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Sistem: ${item.frozenQty}'),
                Text(
                  item.actualQty != null ? 'Aktual: ${item.actualQty}' : 'Belum dihitung',
                  style: const TextStyle(fontSize: 12),
                ),
                if (diff != null)
                  Text(
                    'Selisih: ${diff > 0 ? '+' : ''}$diff',
                    style: TextStyle(color: diffColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
              ],
            ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editQty(context),
              ),
          ],
        ),
      ),
    );
  }

  void _editQty(BuildContext context) {
    final ctrl = TextEditingController(text: '${item.actualQty ?? item.frozenQty}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item.productName} (${item.variantSize})'),
        content: TextFormField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Jumlah Aktual'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(ctrl.text);
              if (qty != null && qty >= 0) {
                onUpdated(qty);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _CreateStockCountDialog extends ConsumerStatefulWidget {
  const _CreateStockCountDialog({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateStockCountDialog> createState() =>
      _CreateStockCountDialogState();
}

class _CreateStockCountDialogState
    extends ConsumerState<_CreateStockCountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  DateTime _plannedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat Sesi Stok Opname'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama Sesi'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal Rencana'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_plannedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _plannedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d != null) setState(() => _plannedDate = d);
              },
            ),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Buat'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/admin/stock-counts',
        data: {
          'name': _name.text,
          'planned_date': DateFormat('yyyy-MM-dd').format(_plannedDate),
          if (_notes.text.isNotEmpty) 'notes': _notes.text,
        },
      );
      widget.onCreated();
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
