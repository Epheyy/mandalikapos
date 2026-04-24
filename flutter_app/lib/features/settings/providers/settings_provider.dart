import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/core/network/api_client.dart';
import 'package:mandalika_pos/features/settings/models/app_settings.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return SettingsNotifier(ref.watch(apiClientProvider));
});

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchSettings();
  }

  final ApiClient _api;

  Future<void> fetchSettings() async {
    state = const AsyncValue.loading();
    try {
      final response =
          await _api.get<Map<String, dynamic>>('/admin/settings');
      state = AsyncValue.data(
        response.data != null
            ? AppSettings.fromJson(response.data!)
            : _defaultSettings,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _api.put<Map<String, dynamic>>(
      '/admin/settings',
      data: settings.toJson(),
    );
    state = AsyncValue.data(settings);
  }

  static final _defaultSettings = AppSettings(
    taxEnabled: false,
    taxRate: 11.0,
    roundingEnabled: false,
    roundingType: 'none',
    paymentMethods: const [
      PaymentMethodConfig(id: 'cash', label: 'Tunai', isEnabled: true),
      PaymentMethodConfig(id: 'card', label: 'Kartu', isEnabled: true),
      PaymentMethodConfig(id: 'transfer', label: 'Transfer', isEnabled: true),
      PaymentMethodConfig(id: 'qris', label: 'QRIS', isEnabled: true),
    ],
    receipt: const ReceiptSettings(
      headerText: 'Mandalika Perfume',
      footerText: 'Terima kasih telah berbelanja!',
      showTax: false,
      showCashier: true,
      copies: 1,
      autoPrint: false,
      showOrderNumber: true,
      showCustomerName: true,
      showDiscount: true,
      showSubtotal: true,
      showChange: true,
    ),
    autoOpenShift: false,
  );
}
