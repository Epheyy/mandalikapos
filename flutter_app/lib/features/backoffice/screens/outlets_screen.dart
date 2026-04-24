import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/outlets/models/outlet.dart';
import 'package:mandalika_pos/features/outlets/providers/outlets_provider.dart';

class OutletsScreen extends ConsumerWidget {
  const OutletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outletsAsync = ref.watch(outletsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outlet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(outletsProvider),
          ),
          FilledButton.icon(
            onPressed: () => _showForm(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Tambah'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: outletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (outlets) => outlets.isEmpty
            ? const Center(child: Text('Belum ada outlet'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: outlets.length,
                itemBuilder: (ctx, i) => _OutletCard(
                  outlet: outlets[i],
                  onMutated: () => ref.invalidate(outletsProvider),
                ),
              ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Outlet? outlet) {
    showDialog(
      context: context,
      builder: (_) => _OutletFormDialog(
        outlet: outlet,
        onSaved: () => ref.invalidate(outletsProvider),
      ),
    );
  }
}

class _OutletCard extends StatelessWidget {
  const _OutletCard({required this.outlet, required this.onMutated});
  final Outlet outlet;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
          child: const Icon(Icons.store, color: Color(0xFF6366F1)),
        ),
        title: Text(outlet.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outlet.address != null) Text(outlet.address!),
            if (outlet.phone != null) Text(outlet.phone!),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (outlet.isActive ? Colors.green : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(outlet.isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                      color: outlet.isActive ? Colors.green : Colors.grey,
                      fontSize: 11)),
            ),
            Consumer(
              builder: (ctx, ref, _) => PopupMenuButton<String>(
                onSelected: (v) => _onAction(ctx, ref, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Nonaktifkan', style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: outlet.address != null,
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'edit') {
      showDialog(
        context: context,
        builder: (_) => _OutletFormDialog(outlet: outlet, onSaved: onMutated),
      );
    } else if (action == 'delete') {
      _confirmDeactivate(context, ref);
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Outlet'),
        content: Text('Yakin ingin menonaktifkan "${outlet.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/admin/outlets/${outlet.id}');
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

class _OutletFormDialog extends ConsumerStatefulWidget {
  const _OutletFormDialog({this.outlet, required this.onSaved});
  final Outlet? outlet;
  final VoidCallback onSaved;

  @override
  ConsumerState<_OutletFormDialog> createState() => _OutletFormDialogState();
}

class _OutletFormDialogState extends ConsumerState<_OutletFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.outlet?.name ?? '');
    _address = TextEditingController(text: widget.outlet?.address ?? '');
    _phone = TextEditingController(text: widget.outlet?.phone ?? '');
    _isActive = widget.outlet?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.outlet == null ? 'Tambah Outlet' : 'Edit Outlet'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama Outlet'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Alamat'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telepon'),
              keyboardType: TextInputType.phone,
            ),
            if (widget.outlet != null)
              SwitchListTile(
                title: const Text('Aktif'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
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
        if (_address.text.isNotEmpty) 'address': _address.text,
        if (_phone.text.isNotEmpty) 'phone': _phone.text,
        'is_active': _isActive,
      };
      if (widget.outlet == null) {
        await api.post<Map<String, dynamic>>('/admin/outlets', data: body);
      } else {
        await api.put<Map<String, dynamic>>(
            '/admin/outlets/${widget.outlet!.id}', data: body);
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
