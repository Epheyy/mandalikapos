import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/outlets/models/outlet.dart';

final outletsProvider =
    FutureProvider.autoDispose<List<Outlet>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/outlets');
  final data = response.data ?? [];
  return data
      .map((e) => Outlet.fromJson(e as Map<String, dynamic>))
      .toList();
});
