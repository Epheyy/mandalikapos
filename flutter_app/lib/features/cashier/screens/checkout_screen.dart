import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/models/cart_item.dart';
import '../../orders/models/order.dart';
import '../../products/providers/products_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/bluetooth/printer_service.dart';
import '../../../shared/theme/app_theme.dart';

final _idr = NumberFormat.currency(
    locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

const double _taxRate = 0.11;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'cash';
  final _amountPaidController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  final _paymentMethods = [
    {'id': 'cash', 'label': 'Tunai', 'icon': Icons.payments_rounded},
    {'id': 'qris', 'label': 'QRIS', 'icon': Icons.qr_code_rounded},
    {'id': 'card', 'label': 'Kartu', 'icon': Icons.credit_card_rounded},
    {'id': 'transfer', 'label': 'Transfer', 'icon': Icons.swap_horiz_rounded},
  ];

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  int get _subtotal => ref.read(cartTotalsProvider).subtotal;
  int get _taxAmount => (_subtotal * _taxRate).round();
  int get _total => _subtotal + _taxAmount;
  int get _amountPaid =>
      int.tryParse(_amountPaidController.text.replaceAll('.', '')) ?? 0;
  int get _change => (_amountPaid - _total).clamp(0, 999999999);
  bool get _canPay =>
      _paymentMethod != 'cash' || _amountPaid >= _total;

Future<void> _processPayment() async {
  setState(() {
    _isProcessing = true;
    _errorMessage = null;
  });

  final confirmedTotal = _total;
  final confirmedChange = _paymentMethod == 'cash' ? _change : 0;

  // Snapshot cart before clearing
  final cartSnapshot = List<CartItem>.from(ref.read(cartProvider));

  try {
    final cartItems = ref.read(cartProvider);
    final api = ref.read(apiClientProvider);

    final orderItems = cartItems.map((item) => OrderItemRequest(
          productId: item.productId,
          variantId: item.variantId,
          productName: item.productName,
          variantSize: item.variantSize,
          price: item.price,
          quantity: item.quantity,
          subtotal: item.subtotal,
        )).toList();

    final request = CreateOrderRequest(
      items: orderItems,
      subtotal: _subtotal,
      discountAmount: 0,
      taxAmount: _taxAmount,
      total: _total,
      paymentMethod: _paymentMethod,
      amountPaid: _paymentMethod == 'cash' ? _amountPaid : _total,
      changeAmount: _paymentMethod == 'cash' ? _change : 0,
      outletId: '',
    );

    final response = await api.post('/orders', data: request.toJson());

    // Extract order number from response
    final orderNumber =
        (response.data as Map<String, dynamic>?)?['order_number']
            as String? ?? 'MND-XXXXXX';

    ref.read(cartProvider.notifier).clearCart();
    ref.invalidate(productsProvider);

    if (mounted) {
      _showSuccessDialog(confirmedTotal, confirmedChange, orderNumber, cartSnapshot);
    }
  } on DioException catch (e) {
    setState(() {
      _errorMessage = e.message ?? 'Gagal memproses pembayaran';
    });
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}

  void _showSuccessDialog(
  int total,
  int change,
  String orderNumber,
  List<CartItem> items,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SuccessDialog(
      total: total,
      change: change,
      paymentMethod: _paymentMethod,
      orderNumber: orderNumber,
      items: items,
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      amountPaid: _paymentMethod == 'cash' ? _amountPaid : total,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Order summary card
            _SectionCard(
              title: 'Ringkasan Pesanan',
              child: Column(
                children: [
                  ...cartItems.map((item) => _OrderItemRow(item: item)),
                  const Divider(height: 24),
                  _TotalRow('Subtotal', _subtotal),
                  const SizedBox(height: 4),
                  _TotalRow('PPN 11%', _taxAmount,
                      color: AppTheme.textSecondary),
                  const SizedBox(height: 8),
                  _TotalRow('Total', _total,
                      isBold: true, color: AppTheme.primaryGold),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment method
            _SectionCard(
              title: 'Metode Pembayaran',
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.5,
                children: _paymentMethods.map((pm) {
                  final isSelected = _paymentMethod == pm['id'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _paymentMethod = pm['id'] as String),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGoldLight
                            : AppTheme.backgroundGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGold
                              : AppTheme.borderGray,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(pm['icon'] as IconData,
                              size: 18,
                              color: isSelected
                                  ? AppTheme.primaryGold
                                  : AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(pm['label'] as String,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppTheme.primaryGoldDark
                                      : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Cash input
            if (_paymentMethod == 'cash') ...[
              _SectionCard(
                title: 'Jumlah Bayar',
                child: Column(
                  children: [
                    // Quick amount buttons
                    Wrap(
                      spacing: 8,
                      children: {_total, _roundUp(_total, 50000),
                        _roundUp(_total, 100000)}.take(3)
                          .map((amount) => ActionChip(
                                label: Text(_idr.format(amount)),
                                onPressed: () => setState(() =>
                                    _amountPaidController.text =
                                        amount.toString()),
                                backgroundColor:
                                    AppTheme.primaryGoldLight,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountPaidController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Masukkan jumlah...',
                        prefixText: 'Rp ',
                      ),
                    ),
                    if (_amountPaid >= _total && _amountPaid > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kembalian',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.success)),
                            Text(_idr.format(_change),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: AppTheme.success)),
                          ],
                        ),
                      ),
                    ],
                    if (_amountPaid > 0 && _amountPaid < _total) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kurang',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.error)),
                            Text(_idr.format(_total - _amountPaid),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: AppTheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppTheme.error)),
              ),

            // Pay button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (!_isProcessing && _canPay) ? _processPayment : null,
                child: _isProcessing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Konfirmasi Pembayaran · ${_idr.format(_total)}'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderGray),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _OrderItemRow extends StatelessWidget {
  final CartItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text('${item.productName} ${item.variantSize} ×${item.quantity}',
                  style: const TextStyle(fontSize: 13)),
            ),
            Text(_idr.format(item.subtotal),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isBold;
  final Color? color;

  const _TotalRow(this.label, this.amount,
      {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight:
                      isBold ? FontWeight.w900 : FontWeight.w400,
                  color: color ?? AppTheme.textPrimary)),
          Text(_idr.format(amount),
              style: TextStyle(
                  fontWeight:
                      isBold ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isBold ? 18 : 14,
                  color: color ?? AppTheme.textPrimary)),
        ],
      );
}

int _roundUp(int amount, int to) {
  return ((amount / to).ceil() * to);
}

class _SuccessDialog extends ConsumerWidget {
  final int total;
  final int change;
  final String paymentMethod;
  final String orderNumber;
  final List<CartItem> items;
  final int subtotal;
  final int taxAmount;
  final int amountPaid;

  const _SuccessDialog({
    required this.total,
    required this.change,
    required this.paymentMethod,
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.amountPaid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idr = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final printerStatus = ref.watch(printerStatusProvider);
    final isPrinting = printerStatus == PrinterStatus.printing;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 48),
          ),
          const SizedBox(height: 16),
          const Text('Pembayaran Berhasil!',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 4),
          Text(orderNumber,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(idr.format(total),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGold)),
          if (paymentMethod == 'cash' && change > 0) ...[
            const SizedBox(height: 8),
            Text('Kembalian: ${idr.format(change)}',
                style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ],
      ),
      actions: [
        // Print receipt button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isPrinting
                ? null
                : () async {
                    final printerService = ref.read(printerServiceProvider);
                    ref.read(printerStatusProvider.notifier).state =
                        PrinterStatus.printing;

                    final error = await printerService.printReceipt(
                      orderNumber: orderNumber,
                      items: items,
                      subtotal: subtotal,
                      taxAmount: taxAmount,
                      total: total,
                      paymentMethod: paymentMethod,
                      amountPaid: amountPaid,
                      change: change,
                      cashierName: 'Kasir',
                    );

                    ref.read(printerStatusProvider.notifier).state =
                        PrinterStatus.connected;

                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  },
            icon: isPrinting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_rounded),
            label: Text(isPrinting ? 'Mencetak...' : 'Cetak Struk'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryGold),
              foregroundColor: AppTheme.primaryGold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // New transaction button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to cashier
            },
            child: const Text('Transaksi Baru'),
          ),
        ),
      ],
    );
  }
}