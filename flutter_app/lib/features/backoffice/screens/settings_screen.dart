import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mandalika_pos/features/settings/models/app_settings.dart';
import 'package:mandalika_pos/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => _SettingsForm(settings: settings),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _taxEnabled;
  late double _taxRate;
  late bool _roundingEnabled;
  late bool _autoOpenShift;
  late List<PaymentMethodConfig> _paymentMethods;
  late TextEditingController _headerCtrl;
  late TextEditingController _footerCtrl;
  late bool _showTax;
  late bool _showCashier;
  late int _copies;
  late bool _autoPrint;
  late bool _showOrderNumber;
  late bool _showCustomerName;
  late bool _showDiscount;
  late bool _showSubtotal;
  late bool _showChange;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init(widget.settings);
  }

  @override
  void didUpdateWidget(_SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _init(widget.settings);
    }
  }

  void _init(AppSettings s) {
    _taxEnabled = s.taxEnabled;
    _taxRate = s.taxRate;
    _roundingEnabled = s.roundingEnabled;
    _autoOpenShift = s.autoOpenShift;
    _paymentMethods = List.from(s.paymentMethods);
    _headerCtrl = TextEditingController(text: s.receipt.headerText);
    _footerCtrl = TextEditingController(text: s.receipt.footerText);
    _showTax = s.receipt.showTax;
    _showCashier = s.receipt.showCashier;
    _copies = s.receipt.copies;
    _autoPrint = s.receipt.autoPrint;
    _showOrderNumber = s.receipt.showOrderNumber;
    _showCustomerName = s.receipt.showCustomerName;
    _showDiscount = s.receipt.showDiscount;
    _showSubtotal = s.receipt.showSubtotal;
    _showChange = s.receipt.showChange;
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(context, 'Pajak & Pembulatan', [
            SwitchListTile(
              title: const Text('Aktifkan PPN'),
              subtitle: const Text('Tambahkan pajak ke total transaksi'),
              value: _taxEnabled,
              onChanged: (v) => setState(() => _taxEnabled = v),
            ),
            if (_taxEnabled)
              ListTile(
                title: const Text('Tarif PPN (%)'),
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _taxRate.toStringAsFixed(1),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(suffix: Text('%')),
                    onChanged: (v) => _taxRate = double.tryParse(v) ?? _taxRate,
                  ),
                ),
              ),
            SwitchListTile(
              title: const Text('Pembulatan'),
              subtitle: const Text('Bulatkan total ke Rp 100 terdekat'),
              value: _roundingEnabled,
              onChanged: (v) => setState(() => _roundingEnabled = v),
            ),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Shift', [
            SwitchListTile(
              title: const Text('Buka Shift Otomatis'),
              subtitle: const Text('Langsung buka shift tanpa memasukkan kas awal'),
              value: _autoOpenShift,
              onChanged: (v) => setState(() => _autoOpenShift = v),
            ),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Metode Pembayaran', [
            ..._paymentMethods.asMap().entries.map((e) {
              final m = e.value;
              return SwitchListTile(
                title: Text(m.label),
                value: m.isEnabled,
                onChanged: (v) => setState(() {
                  _paymentMethods[e.key] = m.copyWith(isEnabled: v);
                }),
              );
            }),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Pengaturan Struk', [
            TextFormField(
              controller: _headerCtrl,
              decoration: const InputDecoration(
                labelText: 'Header Struk',
                helperText: 'Teks di bagian atas struk',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _footerCtrl,
              decoration: const InputDecoration(
                labelText: 'Footer Struk',
                helperText: 'Teks di bagian bawah struk',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Jumlah Salinan'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                  ),
                  Text('$_copies'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _copies < 5 ? () => setState(() => _copies++) : null,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Cetak Otomatis'),
              value: _autoPrint,
              onChanged: (v) => setState(() => _autoPrint = v),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('Tampilkan di Struk', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            _switchTile('Nomor Pesanan', _showOrderNumber, (v) => setState(() => _showOrderNumber = v)),
            _switchTile('Nama Pelanggan', _showCustomerName, (v) => setState(() => _showCustomerName = v)),
            _switchTile('Diskon', _showDiscount, (v) => setState(() => _showDiscount = v)),
            _switchTile('Subtotal', _showSubtotal, (v) => setState(() => _showSubtotal = v)),
            _switchTile('Kembalian', _showChange, (v) => setState(() => _showChange = v)),
            _switchTile('Pajak', _showTax, (v) => setState(() => _showTax = v)),
            _switchTile('Nama Kasir', _showCashier, (v) => setState(() => _showCashier = v)),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan Pengaturan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String title, bool value, void Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = AppSettings(
        taxEnabled: _taxEnabled,
        taxRate: _taxRate,
        roundingEnabled: _roundingEnabled,
        roundingType: _roundingEnabled ? 'round100' : 'none',
        paymentMethods: _paymentMethods,
        receipt: ReceiptSettings(
          headerText: _headerCtrl.text,
          footerText: _footerCtrl.text,
          showTax: _showTax,
          showCashier: _showCashier,
          copies: _copies,
          autoPrint: _autoPrint,
          showOrderNumber: _showOrderNumber,
          showCustomerName: _showCustomerName,
          showDiscount: _showDiscount,
          showSubtotal: _showSubtotal,
          showChange: _showChange,
        ),
        autoOpenShift: _autoOpenShift,
      );
      await ref.read(settingsProvider.notifier).updateSettings(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
