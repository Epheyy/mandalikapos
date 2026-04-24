import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mandalika_pos/features/auth/providers/auth_provider.dart';

final _backofficeIndexProvider = StateProvider<int>((ref) => 0);

class BackOfficeShell extends ConsumerWidget {
  const BackOfficeShell({required this.child, super.key});

  final Widget child;

  static const _items = [
    _NavItem(label: 'Dashboard', icon: LucideIcons.layoutDashboard, path: '/backoffice/dashboard'),
    _NavItem(label: 'Pesanan', icon: LucideIcons.shoppingBag, path: '/backoffice/orders'),
    _NavItem(label: 'Produk', icon: LucideIcons.package, path: '/backoffice/products'),
    _NavItem(label: 'Pelanggan', icon: LucideIcons.users, path: '/backoffice/customers'),
    _NavItem(label: 'Promosi', icon: LucideIcons.tag, path: '/backoffice/promotions'),
    _NavItem(label: 'Laporan', icon: LucideIcons.barChart2, path: '/backoffice/reports'),
    _NavItem(label: 'Pengaturan', icon: LucideIcons.settings, path: '/backoffice/settings'),
    _NavItem(label: 'Stok Opname', icon: LucideIcons.clipboardList, path: '/backoffice/stock-count'),
    _NavItem(label: 'Pengguna', icon: LucideIcons.userCog, path: '/backoffice/users'),
    _NavItem(label: 'Outlet', icon: LucideIcons.store, path: '/backoffice/outlets'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(_backofficeIndexProvider);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) {
              ref.read(_backofficeIndexProvider.notifier).state = i;
              context.go(_items[i].path);
            },
            extended: MediaQuery.of(context).size.width > 1000,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(LucideIcons.flower2, size: 28, color: Color(0xFF6366F1)),
                  const SizedBox(height: 4),
                  Text(
                    'Mandalika',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.shoppingCart),
                        tooltip: 'Kasir',
                        onPressed: () => context.go('/'),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.logOut),
                        tooltip: 'Keluar',
                        onPressed: () =>
                            ref.read(authServiceProvider).signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: _items
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}
