import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/features/backoffice/models/dashboard_stats.dart';
import 'package:mandalika_pos/features/backoffice/providers/dashboard_provider.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => _DashboardContent(stats: stats),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ringkasan Hari Ini',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _KpiRow(stats: stats),
          const SizedBox(height: 32),
          Text('Penjualan 7 Hari Terakhir',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(height: 220, child: _SalesChart(data: stats.salesByDay)),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Produk Terlaris',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _TopProductsList(products: stats.topProducts),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metode Pembayaran',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _PaymentBreakdown(breakdown: stats.paymentBreakdown),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Penjualan Hari Ini',
            value: _idr.format(stats.todaySales),
            color: const Color(0xFF6366F1),
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            label: 'Transaksi Hari Ini',
            value: '${stats.todayOrders}',
            color: const Color(0xFF10B981),
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            label: 'Pelanggan Baru',
            value: '${stats.todayCustomers}',
            color: const Color(0xFFF59E0B),
            icon: Icons.people,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _KpiCard(
            label: 'Penjualan Bulan Ini',
            value: _idr.format(stats.monthSales),
            color: const Color(0xFFEF4444),
            icon: Icons.calendar_month,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    )),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.data});

  final List<DaySales> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Belum ada data'));

    final maxY = data.map((d) => d.sales).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY.toDouble() * 1.2,
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.sales.toDouble(),
                color: const Color(0xFF6366F1),
                width: 24,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                final date = data[idx].date;
                final parts = date.split('-');
                return Text(
                  parts.length >= 3 ? '${parts[2]}/${parts[1]}' : date,
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                _idr.format(value.toInt()),
                style: const TextStyle(fontSize: 9),
              ),
              reservedSize: 80,
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Text('Belum ada data');
    }
    return Card(
      child: Column(
        children: products.asMap().entries.map((e) {
          final p = e.value;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
              child: Text('${e.key + 1}',
                  style: const TextStyle(
                      color: Color(0xFF6366F1), fontSize: 12)),
            ),
            title: Text('${p.productName} (${p.variantSize})'),
            trailing: Text('${p.quantity} pcs',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }
}

class _PaymentBreakdown extends StatelessWidget {
  const _PaymentBreakdown({required this.breakdown});

  final List<PaymentBreakdown> breakdown;

  static const _colors = [
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static const _labels = {
    'cash': 'Tunai',
    'card': 'Kartu',
    'transfer': 'Transfer',
    'qris': 'QRIS',
  };

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Belum ada data')));
    }

    final total = breakdown.fold<int>(0, (sum, b) => sum + b.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: breakdown.asMap().entries.map((e) {
            final b = e.value;
            final pct = total > 0 ? (b.amount / total * 100) : 0.0;
            final color = _colors[e.key % _colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_labels[b.method] ?? b.method),
                      Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: total > 0 ? b.amount / total : 0,
                    backgroundColor: color.withOpacity(0.1),
                    color: color,
                  ),
                  const SizedBox(height: 2),
                  Text(_idr.format(b.amount),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
