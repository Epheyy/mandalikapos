import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/customers/models/customer.dart';

final customersProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/customers');
  final data = response.data ?? [];
  return data
      .map((e) => Customer.fromJson(e as Map<String, dynamic>))
      .toList();
});

final customerByPhoneProvider =
    FutureProvider.autoDispose.family<Customer?, String>((ref, phone) async {
  if (phone.isEmpty) return null;
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get<Map<String, dynamic>>(
      '/customers',
      params: {'phone': phone},
    );
    if (response.data == null) return null;
    return Customer.fromJson(response.data!);
  } catch (_) {
    return null;
  }
});
