import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/core/network/api_client.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy HH:mm');

// Filter state
class _OrderFilter {
  const _OrderFilter({
    this.from,
    this.to,
    this.status,
    this.paymentMethod,
  });

  final DateTime? from;
  final DateTime? to;
  final String? status;
  final String? paymentMethod;
}

final _filterProvider = StateProvider<_OrderFilter>((ref) => const _OrderFilter());

final _ordersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(_filterProvider);
  final params = <String, dynamic>{};
  if (filter.from != null) params['from'] = filter.from!.toIso8601String().substring(0, 10);
  if (filter.to != null) params['to'] = filter.to!.toIso8601String().substring(0, 10);
  if (filter.status != null) params['status'] = filter.status;
  if (filter.paymentMethod != null) params['payment_method'] = filter.paymentMethod;
  final response = await api.get<List<dynamic>>('/admin/orders', params: params);
  final data = response.data ?? [];
  return data.cast<Map<String, dynamic>>();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_ordersProvider);
    final filter = ref.watch(_filterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_ordersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) => orders.isEmpty
                  ? const Center(child: Text('Tidak ada pesanan'))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) => _OrderTile(order: orders[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});
  final _OrderFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _dateChip(context, ref, 'Dari', filter.from, (d) {
            ref.read(_filterProvider.notifier).state =
                _OrderFilter(from: d, to: filter.to, status: filter.status, paymentMethod: filter.paymentMethod);
          }),
          _dateChip(context, ref, 'Sampai', filter.to, (d) {
            ref.read(_filterProvider.notifier).state =
                _OrderFilter(from: filter.from, to: d, status: filter.status, paymentMethod: filter.paymentMethod);
          }),
          _dropChip(
            'Status',
            filter.status,
            const ['pending', 'completed', 'refunded'],
            (v) => ref.read(_filterProvider.notifier).state =
                _OrderFilter(from: filter.from, to: filter.to, status: v, paymentMethod: filter.paymentMethod),
          ),
          _dropChip(
            'Pembayaran',
            filter.paymentMethod,
            const ['cash', 'card', 'transfer', 'qris'],
            (v) => ref.read(_filterProvider.notifier).state =
                _OrderFilter(from: filter.from, to: filter.to, status: filter.status, paymentMethod: v),
          ),
          if (filter.from != null || filter.to != null || filter.status != null || filter.paymentMethod != null)
            ActionChip(
              label: const Text('Reset'),
              onPressed: () => ref.read(_filterProvider.notifier).state = const _OrderFilter(),
            ),
        ],
      ),
    );
  }

  Widget _dateChip(BuildContext context, WidgetRef ref, String label, DateTime? value, void Function(DateTime?) onPick) {
    return ActionChip(
      label: Text(value != null ? '$label: ${DateFormat('dd/MM/yy').format(value)}' : label),
      avatar: const Icon(Icons.calendar_today, size: 16),
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onPick(d);
      },
    );
  }

  Widget _dropChip(String label, String? value, List<String> options, void Function(String?) onChanged) {
    return DropdownButton<String>(
      hint: Text(label),
      value: value,
      underline: const SizedBox(),
      items: [
        DropdownMenuItem(value: null, child: Text('Semua $label')),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: onChanged,
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order['status'] as String? ?? '';
    final total = (order['total'] as num?)?.toInt() ?? 0;
    final createdAt = order['created_at'] as String?;
    final payMethod = order['payment_method'] as String? ?? '';
    final orderNum = order['order_number'] as String? ?? order['id'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text('#$orderNum'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(createdAt != null ? _dateFmt.format(DateTime.parse(createdAt)) : ''),
            Text('$payMethod • ${_idr.format(total)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusBadge(status: status),
            if (status == 'completed')
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.orange),
                tooltip: 'Refund',
                onPressed: () => _confirmRefund(context, ref, order['id'] as String),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showDetail(context, order),
      ),
    );
  }

  Future<void> _confirmRefund(BuildContext context, WidgetRef ref, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Refund'),
        content: const Text('Yakin ingin melakukan refund pesanan ini? Stok akan dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Refund')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.put<Map<String, dynamic>>('/orders/$orderId/refund', data: {});
      ref.invalidate(_ordersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refund berhasil')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal refund: $e')),
        );
      }
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detail Pesanan #${order['order_number'] ?? order['id']}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...items.map((item) {
                final m = item as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  title: Text('${m['product_name']} (${m['variant_size']})'),
                  trailing: Text(
                    '${m['quantity']}x ${_idr.format((m['price'] as num?)?.toInt() ?? 0)}',
                  ),
                );
              }),
              const Divider(),
              if (order['discount_amount'] != null && (order['discount_amount'] as num) > 0)
                ListTile(
                  dense: true,
                  title: const Text('Diskon'),
                  trailing: Text('-${_idr.format((order['discount_amount'] as num).toInt())}'),
                ),
              ListTile(
                dense: true,
                title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  _idr.format((order['total'] as num?)?.toInt() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Catatan: ${order['notes']}',
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'completed' => (Colors.green, 'Selesai'),
      'refunded' => (Colors.orange, 'Refund'),
      'pending' => (Colors.blue, 'Pending'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
