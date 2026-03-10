import 'dart:async';
import 'dart:convert';
import 'dart:io' show Socket;
import 'package:flutter/foundation.dart';
import '../data/local/app_database.dart';

enum PrinterConnectionType { lan, bluetooth, usb }

class PrinterCandidate {
  const PrinterCandidate({
    required this.name,
    required this.address,
    required this.connectionType,
    this.vendorId,
    this.productId,
  });

  final String name;
  final String address;
  final PrinterConnectionType connectionType;
  final String? vendorId;
  final String? productId;
}

class LastReceiptPayload {
  const LastReceiptPayload({
    required this.invoiceNumber,
    required this.total,
    required this.lines,
    required this.printedAt,
  });

  final String invoiceNumber;
  final double total;
  final List<String> lines;
  final DateTime printedAt;

  Map<String, dynamic> toJson() {
    return {
      'invoice_number': invoiceNumber,
      'total': total,
      'lines': lines,
      'printed_at': printedAt.toIso8601String(),
    };
  }

  factory LastReceiptPayload.fromJson(Map<String, dynamic> json) {
    return LastReceiptPayload(
      invoiceNumber: (json['invoice_number'] ?? '') as String,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      lines: ((json['lines'] ?? const []) as List<dynamic>).map((e) => e.toString()).toList(),
      printedAt: DateTime.tryParse((json['printed_at'] ?? '') as String) ?? DateTime.now(),
    );
  }
}

class PrinterService {
  PrinterService({required this.database});

  final AppDatabase database;

  PrinterConnectionType connectionType = PrinterConnectionType.lan;

  String lanIp = '';
  int lanPort = 9100;

  String bluetoothMac = '';
  String usbVendorId = '';
  String usbProductId = '';
  LastReceiptPayload? _lastReceipt;

  bool get hasLastReceipt => _lastReceipt != null;
  LastReceiptPayload? get lastReceipt => _lastReceipt;

  Future<void> loadConfig() async {
    final typeRaw = (await database.getSetting('printer_connection_type') ?? 'LAN').toString().toUpperCase();
    connectionType = _parseType(typeRaw);

    lanIp = (await database.getSetting('printer_lan_ip') ?? '').trim();
    lanPort = int.tryParse(await database.getSetting('printer_lan_port') ?? '') ?? 9100;

    bluetoothMac = (await database.getSetting('printer_bt_mac') ?? '').trim();
    usbVendorId = (await database.getSetting('printer_usb_vendor_id') ?? '').trim();
    usbProductId = (await database.getSetting('printer_usb_product_id') ?? '').trim();

    final payloadRaw = await database.getSetting('printer_last_receipt');
    if (payloadRaw != null && payloadRaw.isNotEmpty) {
      try {
        _lastReceipt = LastReceiptPayload.fromJson(jsonDecode(payloadRaw) as Map<String, dynamic>);
      } catch (_) {
        _lastReceipt = null;
      }
    }
  }

  Future<void> saveConfig({
    required PrinterConnectionType type,
    required String lanIp,
    required int lanPort,
    required String bluetoothMac,
    required String usbVendorId,
    required String usbProductId,
  }) async {
    connectionType = type;
    this.lanIp = lanIp.trim();
    this.lanPort = lanPort;
    this.bluetoothMac = bluetoothMac.trim();
    this.usbVendorId = usbVendorId.trim();
    this.usbProductId = usbProductId.trim();

    await database.setSetting('printer_connection_type', _typeToRaw(connectionType));
    await database.setSetting('printer_lan_ip', this.lanIp);
    await database.setSetting('printer_lan_port', '${this.lanPort}');
    await database.setSetting('printer_bt_mac', this.bluetoothMac);
    await database.setSetting('printer_usb_vendor_id', this.usbVendorId);
    await database.setSetting('printer_usb_product_id', this.usbProductId);
  }

  Future<List<PrinterCandidate>> scanPrinters(PrinterConnectionType type) async {
    // Web safe mock
    return [];
  }

  Future<String> printReceipt({
    required String invoiceNumber,
    required double total,
    List<String> lines = const [],
  }) async {
    switch (connectionType) {
      case PrinterConnectionType.lan:
        final result = await _printLan(invoiceNumber: invoiceNumber, total: total, lines: lines);
        await _rememberLastReceipt(invoiceNumber: invoiceNumber, total: total, lines: lines);
        return result;
      case PrinterConnectionType.bluetooth:
        final result = await _printBluetooth(invoiceNumber: invoiceNumber, total: total, lines: lines);
        await _rememberLastReceipt(invoiceNumber: invoiceNumber, total: total, lines: lines);
        return result;
      case PrinterConnectionType.usb:
        final result = await _printUsb(invoiceNumber: invoiceNumber, total: total, lines: lines);
        await _rememberLastReceipt(invoiceNumber: invoiceNumber, total: total, lines: lines);
        return result;
    }
  }

  Future<String> testPrint() async {
    return printReceipt(
      invoiceNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      total: 0,
      lines: const ['*** TEST PRINT ***'],
    );
  }

  Future<String> reprintLastReceipt() async {
    final payload = _lastReceipt;
    if (payload == null) {
      throw Exception('Belum ada struk terakhir untuk dicetak ulang.');
    }

    return printReceipt(
      invoiceNumber: payload.invoiceNumber,
      total: payload.total,
      lines: payload.lines,
    );
  }

  Future<String> _printLan({
    required String invoiceNumber,
    required double total,
    List<String> lines = const [],
  }) async {
    if (lanIp.isEmpty) {
      throw Exception('Printer LAN belum diatur.');
    }
    
    if (kIsWeb) {
      return 'Mock printed (Web) to $lanIp:$lanPort';
    }

    final bytes = await _buildReceiptBytes(invoiceNumber: invoiceNumber, total: total, lines: lines);
    final socket = await Socket.connect(lanIp, lanPort, timeout: const Duration(seconds: 5));
    socket.add(bytes);
    await socket.flush();
    await socket.close();

    return 'Printed to $lanIp:$lanPort';
  }

  Future<String> _printBluetooth({
    required String invoiceNumber,
    required double total,
    List<String> lines = const [],
  }) async {
    if (bluetoothMac.isEmpty) {
      throw Exception('Bluetooth MAC printer belum diatur.');
    }
    return 'Mock printed via Bluetooth $bluetoothMac';
  }

  Future<String> _printUsb({
    required String invoiceNumber,
    required double total,
    List<String> lines = const [],
  }) async {
    if (usbVendorId.isEmpty || usbProductId.isEmpty) {
      throw Exception('USB vendor/product id printer belum diatur.');
    }
    return 'Mock printed via USB $usbVendorId:$usbProductId';
  }

  Future<List<int>> _buildReceiptBytes({
    required String invoiceNumber,
    required double total,
    required List<String> lines,
  }) async {
    final bytes = <int>[];
    return bytes;
  }

  PrinterConnectionType _parseType(String value) {
    switch (value) {
      case 'BLUETOOTH':
        return PrinterConnectionType.bluetooth;
      case 'USB':
        return PrinterConnectionType.usb;
      default:
        return PrinterConnectionType.lan;
    }
  }

  String _typeToRaw(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.lan:
        return 'LAN';
      case PrinterConnectionType.bluetooth:
        return 'BLUETOOTH';
      case PrinterConnectionType.usb:
        return 'USB';
    }
  }

  Future<void> _rememberLastReceipt({
    required String invoiceNumber,
    required double total,
    required List<String> lines,
  }) async {
    final payload = LastReceiptPayload(
      invoiceNumber: invoiceNumber,
      total: total,
      lines: List<String>.from(lines),
      printedAt: DateTime.now(),
    );
    _lastReceipt = payload;
    await database.setSetting('printer_last_receipt', jsonEncode(payload.toJson()));
  }
}
