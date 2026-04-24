import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mandalika_pos/core/network/api_client.dart';

final _idr = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _dateFmt = DateFormat('yyyy-MM-dd');

class _ReportFilter {
  const _ReportFilter({
    required this.from,
    required this.to,
    required this.groupBy,
  });

  final DateTime from;
  final DateTime to;
  final String groupBy;
}

final _reportFilterProvider = StateProvider<_ReportFilter>((ref) => _ReportFilter(
      from: DateTime.now().subtract(const Duration(days: 29)),
      to: DateTime.now(),
      groupBy: 'day',
    ));

final _salesReportProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(_reportFilterProvider);
  final response = await api.get<List<dynamic>>(
    '/admin/reports/sales',
    params: {
      'from': _dateFmt.format(filter.from),
      'to': _dateFmt.format(filter.to),
      'group_by': filter.groupBy,
    },
  );
  final data = response.data ?? [];
  return data.cast<Map<String, dynamic>>();
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_reportFilterProvider);
    final reportAsync = ref.watch(_salesReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_salesReportProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterRow(filter: filter),
            const SizedBox(height: 24),
            reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) => _ReportContent(rows: rows, filter: filter),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.filter});
  final _ReportFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _dateBtn(context, ref, 'Dari', filter.from, (d) {
          if (d != null) {
            ref.read(_reportFilterProvider.notifier).state =
                _ReportFilter(from: d, to: filter.to, groupBy: filter.groupBy);
          }
        }),
        _dateBtn(context, ref, 'Sampai', filter.to, (d) {
          if (d != null) {
            ref.read(_reportFilterProvider.notifier).state =
                _ReportFilter(from: filter.from, to: d, groupBy: filter.groupBy);
          }
        }),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'day', label: Text('Hari')),
            ButtonSegment(value: 'week', label: Text('Minggu')),
            ButtonSegment(value: 'month', label: Text('Bulan')),
          ],
          selected: {filter.groupBy},
          onSelectionChanged: (s) {
            ref.read(_reportFilterProvider.notifier).state =
                _ReportFilter(from: filter.from, to: filter.to, groupBy: s.first);
          },
        ),
      ],
    );
  }

  Widget _dateBtn(BuildContext context, WidgetRef ref, String label, DateTime value, void Function(DateTime?) onPick) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text('$label: ${DateFormat('dd/MM/yyyy').format(value)}'),
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        onPick(d);
      },
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.rows, required this.filter});
  final List<Map<String, dynamic>> rows;
  final _ReportFilter filter;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('Tidak ada data untuk periode ini'));
    }

    final totalRevenue = rows.fold<int>(
        0, (sum, r) => sum + ((r['revenue'] as num?)?.toInt() ?? 0));
    final totalOrders = rows.fold<int>(
        0, (sum, r) => sum + ((r['orders'] as num?)?.toInt() ?? 0));
    final maxRevenue = rows
        .map((r) => (r['revenue'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Pendapatan',
                value: _idr.format(totalRevenue),
                color: const Color(0xFF6366F1),
                icon: Icons.payments,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryCard(
                label: 'Total Transaksi',
                value: '$totalOrders',
                color: const Color(0xFF10B981),
                icon: Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryCard(
                label: 'Rata-rata / Transaksi',
                value: totalOrders > 0
                    ? _idr.format(totalRevenue ~/ totalOrders)
                    : '-',
                color: const Color(0xFFF59E0B),
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Grafik Pendapatan', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: maxRevenue.toDouble() * 1.2,
              barGroups: rows.asMap().entries.map((e) {
                final rev = (e.value['revenue'] as num?)?.toDouble() ?? 0;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: rev,
                      color: const Color(0xFF6366F1),
                      width: rows.length < 15 ? 24 : 12,
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
                      if (idx < 0 || idx >= rows.length) return const SizedBox();
                      final period = rows[idx]['period'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(period.length > 7 ? period.substring(5) : period,
                            style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Text(_idr.format(v.toInt()),
                        style: const TextStyle(fontSize: 8)),
                    reservedSize: 80,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Detail Per Periode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Periode', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Pendapatan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              ...rows.map((r) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(r['period'] as String? ?? ''),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_idr.format((r['revenue'] as num?)?.toInt() ?? 0)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${(r['orders'] as num?)?.toInt() ?? 0}'),
                      ),
                    ],
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
                Flexible(
                  child: Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
