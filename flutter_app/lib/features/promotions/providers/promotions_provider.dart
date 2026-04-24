import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/promotions/models/promotion.dart';

final promotionsProvider =
    FutureProvider.autoDispose<List<Promotion>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/promotions');
  final data = response.data ?? [];
  return data
      .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
      .toList();
});

final activePromotionsProvider =
    FutureProvider.autoDispose<List<Promotion>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/promotions/active');
  final data = response.data ?? [];
  return data
      .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
      .toList();
});

final discountCodesProvider =
    FutureProvider.autoDispose<List<DiscountCode>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/discount-codes');
  final data = response.data ?? [];
  return data
      .map((e) => DiscountCode.fromJson(e as Map<String, dynamic>))
      .toList();
});
