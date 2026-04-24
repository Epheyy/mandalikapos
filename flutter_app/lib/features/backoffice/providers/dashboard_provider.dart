import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/backoffice/models/dashboard_stats.dart';

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>('/admin/dashboard/stats');
  if (response.data == null) throw Exception('Failed to load dashboard');
  return DashboardStats.fromJson(response.data!);
});
