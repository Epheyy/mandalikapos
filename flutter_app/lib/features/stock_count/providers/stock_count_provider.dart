import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/stock_count/models/stock_count.dart';

final stockCountsProvider =
    FutureProvider.autoDispose<List<StockCount>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/stock-counts');
  final data = response.data ?? [];
  return data
      .map((e) => StockCount.fromJson(e as Map<String, dynamic>))
      .toList();
});

final stockCountDetailProvider = FutureProvider.autoDispose
    .family<StockCount, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final response =
      await api.get<Map<String, dynamic>>('/admin/stock-counts/$id');
  if (response.data == null) throw Exception('Stock count not found');
  return StockCount.fromJson(response.data!);
});
