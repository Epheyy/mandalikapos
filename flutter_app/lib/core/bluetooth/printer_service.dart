// Handles all Bluetooth thermal printer operations.
// Uses ESC/POS commands — the universal language of thermal printers.
// ESC/POS = Epson Standard Code for Point of Sale
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../../features/cart/models/cart_item.dart';

final printerServiceProvider = Provider((ref) => PrinterService());

// Represents a discovered Bluetooth device
class BluetoothDevice {
  final String name;
  final String address; // MAC address like "AA:BB:CC:DD:EE:FF"

  const BluetoothDevice({required this.name, required this.address});
}

// Current printer connection state
enum PrinterStatus { disconnected, connecting, connected, printing, error }

final printerStatusProvider =
    StateProvider<PrinterStatus>((ref) => PrinterStatus.disconnected);

final connectedPrinterProvider =
    StateProvider<BluetoothDevice?>((ref) => null);

class PrinterService {
  // Paper width — change to PaperSize.mm80 if you have 80mm printer
  static const PaperSize _paperSize = PaperSize.mm58;

  // ── Device Discovery ──────────────────────────────────────────

  /// Returns list of paired Bluetooth devices.
  /// Only paired devices can be connected — pair first in Android settings.
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices
          .map((d) => BluetoothDevice(
                name: d.name.isEmpty ? 'Unknown Device' : d.name,
                address: d.macAdress,
              ))
          .where((d) => d.address.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  /// Checks if Bluetooth is enabled on this device.
  Future<bool> isBluetoothEnabled() async {
    return await PrintBluetoothThermal.bluetoothEnabled;
  }

  /// Checks if currently connected to a printer.
  Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  // ── Connection ────────────────────────────────────────────────

  /// Connects to a printer by MAC address.
  /// Returns true on success, false on failure.
  Future<bool> connect(String macAddress) async {
    try {
      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      return result;
    } catch (e) {
      debugPrint('Printer connection error: $e');
      return false;
    }
  }

  /// Disconnects from the current printer.
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (e) {
      debugPrint('Printer disconnect error: $e');
    }
  }

  // ── Receipt Printing ──────────────────────────────────────────

  /// Prints a sales receipt.
  /// Returns null on success, error message on failure.
  Future<String?> printReceipt({
    required String orderNumber,
    required List<CartItem> items,
    required int subtotal,
    required int taxAmount,
    required int total,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    required String cashierName,
    String? customerName,
    String? notes,
    bool isReprint = false,
  }) async {
    try {
      final connected = await isConnected();
      if (!connected) {
        return 'Printer tidak terhubung. Hubungkan printer terlebih dahulu.';
      }

      // Build the receipt bytes
      final bytes = await _buildReceiptBytes(
        orderNumber: orderNumber,
        items: items,
        subtotal: subtotal,
        taxAmount: taxAmount,
        total: total,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        change: change,
        cashierName: cashierName,
        customerName: customerName,
        notes: notes,
        isReprint: isReprint,
      );

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes.toList());
      if (!result) {
        return 'Gagal mengirim data ke printer. Coba lagi.';
      }

      return null; // null = success
    } catch (e) {
      debugPrint('Print error: $e');
      return 'Error: $e';
    }
  }

  /// Prints a test page to verify printer is working.
  Future<String?> printTestPage() async {
    try {
      final connected = await isConnected();
      if (!connected) return 'Printer tidak terhubung';

      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      List<int> bytes = [];

      bytes += generator.text('TEST PRINT',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ));
      bytes += generator.text('Mandalika POS',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.hr();
      bytes += generator.text('Printer terhubung dengan sukses!',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
          DateTime.now().toString().substring(0, 19),
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
      bytes += generator.feed(3);
      bytes += generator.cut();

      final result =
          await PrintBluetoothThermal.writeBytes(bytes.toList());
      return result ? null : 'Gagal mencetak halaman tes';
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ── Receipt Builder ───────────────────────────────────────────

  Future<Uint8List> _buildReceiptBytes({
    required String orderNumber,
    required List<CartItem> items,
    required int subtotal,
    required int taxAmount,
    required int total,
    required String paymentMethod,
    required int amountPaid,
    required int change,
    required String cashierName,
    String? customerName,
    String? notes,
    bool isReprint = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    final idr = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    List<int> bytes = [];

    // ── HEADER ────────────────────────────────────────────
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));

    // Store name — big and bold
    bytes += generator.text('MANDALIKA',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));

    bytes += generator.text('Your Scent, Your Statement',
        styles: const PosStyles(align: PosAlign.center, bold: false));

    bytes += generator.hr(ch: '=');

    if (isReprint) {
      bytes += generator.text('*** CETAK ULANG ***',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.emptyLines(1);
    }

    // Order info
    bytes += generator.row([
      PosColumn(
        text: 'No.',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: orderNumber,
        width: 8,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Tanggal', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
          text: dateStr, width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Kasir', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
          text: cashierName, width: 8,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.row([
        PosColumn(
            text: 'Pelanggan', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(
            text: customerName, width: 8,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    // ── ITEMS ─────────────────────────────────────────────
    for (final item in items) {
      // Product name + size on first line
      bytes += generator.text(
        '${item.productName} ${item.variantSize}',
        styles: const PosStyles(bold: true),
      );

      // Qty x price = subtotal on second line
      bytes += generator.row([
        PosColumn(
          text: '  ${item.quantity} x ${idr.format(item.price)}',
          width: 8,
          styles: const PosStyles(bold: false),
        ),
        PosColumn(
          text: idr.format(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    bytes += generator.hr();

    // ── TOTALS ────────────────────────────────────────────
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
          text: idr.format(subtotal), width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (taxAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'PPN 11%', width: 6),
        PosColumn(
            text: idr.format(taxAmount), width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr(ch: '=');

    bytes += generator.row([
      PosColumn(
          text: 'TOTAL', width: 6,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: idr.format(total), width: 6,
          styles: const PosStyles(
              align: PosAlign.right, bold: false)),
    ]);

    bytes += generator.emptyLines(1);

    // Payment info
    final methodLabel = {
      'cash': 'Tunai',
      'qris': 'QRIS',
      'card': 'Kartu',
      'transfer': 'Transfer',
    }[paymentMethod] ?? paymentMethod;

    bytes += generator.row([
      PosColumn(text: 'Bayar ($methodLabel)', width: 6),
      PosColumn(
          text: idr.format(amountPaid), width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (paymentMethod == 'cash' && change > 0) {
      bytes += generator.row([
        PosColumn(
            text: 'Kembalian', width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: idr.format(change), width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    // Notes
    if (notes != null && notes.isNotEmpty) {
      bytes += generator.hr();
      bytes += generator.text('Catatan: $notes',
          styles: const PosStyles(align: PosAlign.center));
    }

    // ── FOOTER ────────────────────────────────────────────
    bytes += generator.hr(ch: '=');
    bytes += generator.text('Terima kasih telah berbelanja!',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('mandalikaperfume.co.id',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.emptyLines(1);

    // Feed and cut paper
    bytes += generator.feed(3);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }
}