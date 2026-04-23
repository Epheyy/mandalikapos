import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/bluetooth/printer_service.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState
    extends ConsumerState<PrinterSettingsScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
  setState(() => _isScanning = true);
  final service = ref.read(printerServiceProvider);

  // Request Bluetooth permissions at runtime (required Android 12+)
  final btScan = await Permission.bluetoothScan.request();
  final btConnect = await Permission.bluetoothConnect.request();
  final location = await Permission.location.request();

  if (btScan.isDenied || btConnect.isDenied) {
    setState(() {
      _message = 'Izin Bluetooth ditolak. Buka Pengaturan → Aplikasi → Mandalika POS → Izin → aktifkan Bluetooth.';
      _isScanning = false;
    });
    return;
  }

  final enabled = await service.isBluetoothEnabled();
  if (!enabled) {
    setState(() {
      _message = 'Bluetooth tidak aktif. Aktifkan Bluetooth terlebih dahulu.';
      _isScanning = false;
    });
    return;
  }

  final devices = await service.getPairedDevices();
  setState(() {
    _devices = devices;
    _isScanning = false;
    if (devices.isEmpty) {
      _message = 'Tidak ada perangkat yang dipasangkan.\n\nPastikan printer RPP02N sudah dipasangkan di Pengaturan Bluetooth Android.';
    }
  });
}

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _message = null;
    });
    ref.read(printerStatusProvider.notifier).state = PrinterStatus.connecting;

    final service = ref.read(printerServiceProvider);
    final success = await service.connect(device.address);

    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        ref.read(printerStatusProvider.notifier).state =
            PrinterStatus.connected;
        ref.read(connectedPrinterProvider.notifier).state = device;
        setState(() => _message = '✅ Terhubung ke ${device.name}');
      } else {
        ref.read(printerStatusProvider.notifier).state = PrinterStatus.error;
        setState(() => _message =
            '❌ Gagal terhubung ke ${device.name}. Pastikan printer menyala.');
      }
    }
  }

  Future<void> _disconnect() async {
    final service = ref.read(printerServiceProvider);
    await service.disconnect();
    ref.read(printerStatusProvider.notifier).state = PrinterStatus.disconnected;
    ref.read(connectedPrinterProvider.notifier).state = null;
    setState(() => _message = 'Printer diputuskan');
  }

  Future<void> _testPrint() async {
    ref.read(printerStatusProvider.notifier).state = PrinterStatus.printing;
    final service = ref.read(printerServiceProvider);
    final error = await service.printTestPage();
    ref.read(printerStatusProvider.notifier).state = PrinterStatus.connected;

    if (mounted) {
      setState(() => _message = error ?? '✅ Halaman tes berhasil dicetak!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(printerStatusProvider);
    final connectedDevice = ref.watch(connectedPrinterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Printer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusColor(status).withAlpha(25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _statusColor(status).withAlpha(76)),
              ),
              child: Row(
                children: [
                  Icon(_statusIcon(status),
                      color: _statusColor(status), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusLabel(status),
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _statusColor(status))),
                        if (connectedDevice != null)
                          Text(connectedDevice.name,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                      ],
                    ),
                  ),
                  if (status == PrinterStatus.connected) ...[
                    TextButton(
                      onPressed: _testPrint,
                      child: const Text('Test'),
                    ),
                    TextButton(
                      onPressed: _disconnect,
                      child: const Text('Putus',
                          style: TextStyle(color: AppTheme.error)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Message
            if (_message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_message!,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 16),
            ],

            // Device list header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Perangkat Bluetooth Tersedia',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                IconButton(
                  onPressed: _isScanning ? null : _loadDevices,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Text(
                '💡 Printer harus sudah dipasangkan (paired) di Pengaturan Bluetooth Android sebelum muncul di sini.',
                style: TextStyle(color: Color(0xFF0369A1), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Device list
            if (_devices.isEmpty && !_isScanning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Tidak ada perangkat ditemukan',
                      style: TextStyle(color: AppTheme.textMuted)),
                ),
              )
            else
              ...(_devices.map((device) {
                final isConnected = connectedDevice?.address == device.address;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.print_rounded,
                      color: isConnected
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
                    title: Text(device.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(device.address,
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppTheme.textMuted)),
                    trailing: isConnected
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Terhubung',
                                style: TextStyle(
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          )
                        : ElevatedButton(
                            onPressed: _isConnecting
                                ? null
                                : () => _connect(device),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                            child: _isConnecting
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                : const Text('Hubungkan',
                                    style: TextStyle(fontSize: 13)),
                          ),
                    onTap: isConnected ? null : () => _connect(device),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.connected:
        return AppTheme.success;
      case PrinterStatus.connecting:
      case PrinterStatus.printing:
        return AppTheme.warning;
      case PrinterStatus.error:
        return AppTheme.error;
      case PrinterStatus.disconnected:
        return AppTheme.textMuted;
    }
  }

  IconData _statusIcon(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.connected:
        return Icons.check_circle_rounded;
      case PrinterStatus.connecting:
        return Icons.sync_rounded;
      case PrinterStatus.printing:
        return Icons.print_rounded;
      case PrinterStatus.error:
        return Icons.error_rounded;
      case PrinterStatus.disconnected:
        return Icons.print_disabled_rounded;
    }
  }

  String _statusLabel(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.connected:
        return 'Printer Terhubung';
      case PrinterStatus.connecting:
        return 'Menghubungkan...';
      case PrinterStatus.printing:
        return 'Mencetak...';
      case PrinterStatus.error:
        return 'Koneksi Gagal';
      case PrinterStatus.disconnected:
        return 'Printer Tidak Terhubung';
    }
  }
}