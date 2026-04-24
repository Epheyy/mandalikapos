import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/shifts/models/shift.dart';

final currentShiftProvider =
    StateNotifierProvider<ShiftNotifier, AsyncValue<Shift?>>((ref) {
  return ShiftNotifier(ref.watch(apiClientProvider));
});

class ShiftNotifier extends StateNotifier<AsyncValue<Shift?>> {
  ShiftNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchCurrentShift();
  }

  final ApiClient _api;

  Future<void> fetchCurrentShift() async {
    state = const AsyncValue.loading();
    try {
      final response =
          await _api.get<Map<String, dynamic>>('/shifts/current');
      state = AsyncValue.data(
        response.data != null ? Shift.fromJson(response.data!) : null,
      );
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<Shift?> openShift({
    required String outletId,
    required int startingCash,
  }) async {
    final response = await _api.post<Map<String, dynamic>>('/shifts/open', data: {
      'outlet_id': outletId,
      'starting_cash': startingCash,
    });
    if (response.data == null) return null;
    final shift = Shift.fromJson(response.data!);
    state = AsyncValue.data(shift);
    return shift;
  }

  Future<Shift?> closeShift({required int closingCash}) async {
    final response = await _api.post<Map<String, dynamic>>('/shifts/close', data: {
      'closing_cash': closingCash,
    });
    if (response.data == null) return null;
    final shift = Shift.fromJson(response.data!);
    state = const AsyncValue.data(null);
    return shift;
  }
}

final shiftsListProvider = FutureProvider.autoDispose<List<Shift>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get<List<dynamic>>('/admin/shifts');
  final data = response.data ?? [];
  return data
      .map((e) => Shift.fromJson(e as Map<String, dynamic>))
      .toList();
});
