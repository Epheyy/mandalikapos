import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/customers/models/customer.dart';
import 'package:mandalika_pos/features/customers/providers/customers_provider.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(customersProvider),
          ),
          FilledButton.icon(
            onPressed: () => _showForm(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (customers) => customers.isEmpty
            ? const Center(child: Text('Belum ada pelanggan'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: customers.length,
                itemBuilder: (ctx, i) => _CustomerTile(
                  customer: customers[i],
                  onMutated: () => ref.invalidate(customersProvider),
                ),
              ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Customer? customer) {
    showDialog(
      context: context,
      builder: (_) => _CustomerFormDialog(
        customer: customer,
        onSaved: () => ref.invalidate(customersProvider),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onMutated});
  final Customer customer;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(customer.name[0].toUpperCase())),
        title: Text(customer.name),
        subtitle: Text('${customer.phone}${customer.email != null ? ' • ${customer.email}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${customer.points} poin',
                    style: const TextStyle(
                        color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                Text(_idr.format(customer.totalSpent),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(width: 8),
            Consumer(
              builder: (ctx, ref, _) => PopupMenuButton<String>(
                onSelected: (v) => _onAction(ctx, ref, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'history', child: Text('Riwayat Transaksi')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: false,
        onTap: () => _showDetail(context),
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'edit') {
      showDialog(
        context: context,
        builder: (_) => _CustomerFormDialog(
          customer: customer,
          onSaved: onMutated,
        ),
      );
    } else if (action == 'history') {
      _showHistory(context, ref);
    } else if (action == 'delete') {
      _confirmDelete(context, ref);
    }
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Telepon', customer.phone),
            if (customer.email != null) _row('Email', customer.email!),
            _row('Poin', '${customer.points}'),
            _row('Total Belanja', _idr.format(customer.totalSpent)),
            _row('Kunjungan', '${customer.visitCount}x'),
            if (customer.lastVisit != null)
              _row('Kunjungan Terakhir', _dateFmt.format(customer.lastVisit!)),
            _row('Terdaftar', _dateFmt.format(customer.createdAt)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerHistoryDialog(customerId: customer.id),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text('Yakin ingin menghapus "${customer.name}"?'),
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
      await ref.read(apiClientProvider).delete('/admin/customers/${customer.id}');
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
                width: 130,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _CustomerHistoryDialog extends ConsumerWidget {
  const _CustomerHistoryDialog({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_customerHistoryProvider(customerId));

    return AlertDialog(
      title: const Text('Riwayat Transaksi'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (orders) => orders.isEmpty
              ? const Text('Belum ada transaksi')
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (ctx, i) {
                    final o = orders[i];
                    final createdAt = o['created_at'] as String?;
                    return ListTile(
                      dense: true,
                      title: Text('#${o['order_number'] ?? o['id']}'),
                      subtitle: Text(createdAt != null
                          ? _dateFmt.format(DateTime.parse(createdAt))
                          : ''),
                      trailing: Text(_idr.format((o['total'] as num?)?.toInt() ?? 0)),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
      ],
    );
  }
}

final _customerHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, customerId) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<List<dynamic>>('/admin/customers/$customerId/orders');
  final data = response.data ?? [];
  return data.cast<Map<String, dynamic>>();
});

class _CustomerFormDialog extends ConsumerStatefulWidget {
  const _CustomerFormDialog({this.customer, required this.onSaved});
  final Customer? customer;
  final VoidCallback onSaved;

  @override
  ConsumerState<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name ?? '');
    _phone = TextEditingController(text: widget.customer?.phone ?? '');
    _email = TextEditingController(text: widget.customer?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telepon'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email (opsional)'),
              keyboardType: TextInputType.emailAddress,
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
      final api = ref.read(apiClientProvider);
      final body = {
        'name': _name.text,
        'phone': _phone.text,
        if (_email.text.isNotEmpty) 'email': _email.text,
      };
      if (widget.customer == null) {
        await api.post<Map<String, dynamic>>('/admin/customers', data: body);
      } else {
        await api.put<Map<String, dynamic>>(
            '/admin/customers/${widget.customer!.id}', data: body);
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
