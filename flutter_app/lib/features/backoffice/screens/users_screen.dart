import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/users/providers/users_provider.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersProvider),
          ),
          FilledButton.icon(
            onPressed: () => _showInviteDialog(context, ref),
            icon: const Icon(Icons.person_add),
            label: const Text('Undang'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) => users.isEmpty
            ? const Center(child: Text('Belum ada pengguna'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (ctx, i) => _UserTile(
                  user: users[i],
                  onMutated: () => ref.invalidate(usersProvider),
                ),
              ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _UserFormDialog(
        onSaved: () => ref.invalidate(usersProvider),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onMutated});
  final Map<String, dynamic> user;
  final VoidCallback onMutated;

  @override
  Widget build(BuildContext context) {
    final name = user['display_name'] as String? ?? user['email'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? 'cashier';
    final isActive = (user['is_active'] as bool?) ?? true;
    final photoUrl = user['photo_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?') : null,
        ),
        title: Text(name),
        subtitle: Text(email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleBadge(role: role),
            const SizedBox(width: 8),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Nonaktif',
                    style: TextStyle(color: Colors.red, fontSize: 11)),
              ),
            Consumer(
              builder: (ctx, ref, _) => PopupMenuButton<String>(
                onSelected: (v) => _onAction(ctx, ref, v),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle_role',
                    child: Text(role == 'admin'
                        ? 'Jadikan Manager'
                        : role == 'manager'
                            ? 'Jadikan Kasir'
                            : 'Jadikan Manager'),
                  ),
                  PopupMenuItem(
                    value: 'toggle_active',
                    child: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'toggle_role') {
      final currentRole = user['role'] as String? ?? 'cashier';
      final newRole = currentRole == 'manager' ? 'cashier' : 'manager';
      _updateUser(context, ref, {'role': newRole});
    } else if (action == 'toggle_active') {
      final isActive = (user['is_active'] as bool?) ?? true;
      _updateUser(context, ref, {'is_active': !isActive});
    }
  }

  Future<void> _updateUser(
      BuildContext context, WidgetRef ref, Map<String, dynamic> body) async {
    try {
      final id = user['id'] as String;
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
        '/admin/users/$id',
        data: body,
      );
      onMutated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (role) {
      'admin' => (Colors.purple, 'Admin'),
      'manager' => (Colors.blue, 'Manager'),
      _ => (const Color(0xFF10B981), 'Kasir'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _UserFormDialog extends ConsumerStatefulWidget {
  const _UserFormDialog({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _role = 'cashier';
  bool _saving = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Undang Pengguna Baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (!v.contains('@')) return 'Email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'cashier', child: Text('Kasir')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
              ],
              onChanged: (v) => setState(() => _role = v!),
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
              : const Text('Undang'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post<Map<String, dynamic>>(
        '/admin/users',
        data: {
          'display_name': _nameCtrl.text,
          'email': _emailCtrl.text,
          'role': _role,
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
