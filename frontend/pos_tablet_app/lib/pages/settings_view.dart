import 'package:flutter/material.dart';
import '../state/pos_store.dart';
import '../core/config/app_config.dart';
import '../services/printer_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({required this.store});
  final PosStore store;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late PrinterConnectionType _selectedPrinterType;
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _btMacController;
  late final TextEditingController _usbVendorController;
  late final TextEditingController _usbProductController;

  @override
  void initState() {
    super.initState();
    _selectedPrinterType = widget.store.printerConnectionType;
    _ipController = TextEditingController(text: widget.store.printerLanIp);
    _portController = TextEditingController(text: '${widget.store.printerLanPort}');
    _btMacController = TextEditingController(text: widget.store.printerBluetoothMac);
    _usbVendorController = TextEditingController(text: widget.store.printerUsbVendorId);
    _usbProductController = TextEditingController(text: widget.store.printerUsbProductId);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _btMacController.dispose();
    _usbVendorController.dispose();
    _usbProductController.dispose();
    super.dispose();
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E6F62).withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6F62).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E6F62), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _settingsToggle({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E99))),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF1E6F62)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              border: Border(bottom: BorderSide(color: Color(0xFFD3DBDB))),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF1E6F62), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pengaturan Sistem', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1f2d2e))),
                    Text('Role Anda: ${store.userRole}', style: const TextStyle(color: Color(0xFF6B7A7B), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Konfigurasi Printer ──
                _sectionCard(
                  title: 'Konfigurasi Printer',
                  icon: Icons.print_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<PrinterConnectionType>(
                        value: _selectedPrinterType,
                        decoration: const InputDecoration(labelText: 'Mode Koneksi', filled: true, fillColor: Color(0xFFF9FAFA)),
                        items: const [
                          DropdownMenuItem(value: PrinterConnectionType.lan, child: Text('LAN (TCP/IP)')),
                          DropdownMenuItem(value: PrinterConnectionType.bluetooth, child: Text('Bluetooth')),
                          DropdownMenuItem(value: PrinterConnectionType.usb, child: Text('USB OTG')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedPrinterType = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPrinterType == PrinterConnectionType.lan) ...[
                        TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'IP Printer (contoh: 192.168.1.50)', prefixIcon: Icon(Icons.computer, size: 18), filled: true, fillColor: Color(0xFFF9FAFA))),
                        const SizedBox(height: 8),
                        TextField(controller: _portController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port (default 9100)', prefixIcon: Icon(Icons.settings_ethernet, size: 18), filled: true, fillColor: Color(0xFFF9FAFA))),
                      ],
                      if (_selectedPrinterType == PrinterConnectionType.bluetooth)
                        TextField(controller: _btMacController, decoration: const InputDecoration(labelText: 'Bluetooth MAC (AA:BB:CC:DD:EE:FF)', prefixIcon: Icon(Icons.bluetooth, size: 18), filled: true, fillColor: Color(0xFFF9FAFA))),
                      if (_selectedPrinterType == PrinterConnectionType.usb) ...[
                        TextField(controller: _usbVendorController, decoration: const InputDecoration(labelText: 'USB Vendor ID (hex)', prefixIcon: Icon(Icons.usb, size: 18), filled: true, fillColor: Color(0xFFF9FAFA))),
                        const SizedBox(height: 8),
                        TextField(controller: _usbProductController, decoration: const InputDecoration(labelText: 'USB Product ID (hex)', prefixIcon: Icon(Icons.usb, size: 18), filled: true, fillColor: Color(0xFFF9FAFA))),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_selectedPrinterType == PrinterConnectionType.bluetooth)
                            OutlinedButton.icon(
                              onPressed: store.scanningPrinters ? null : store.scanBluetoothPrinters,
                              icon: const Icon(Icons.bluetooth_searching, size: 16),
                              label: Text(store.scanningPrinters ? 'Scanning...' : 'Scan Bluetooth'),
                            ),
                          if (_selectedPrinterType == PrinterConnectionType.usb)
                            OutlinedButton.icon(
                              onPressed: store.scanningPrinters ? null : store.scanUsbPrinters,
                              icon: const Icon(Icons.usb, size: 16),
                              label: Text(store.scanningPrinters ? 'Scanning...' : 'Scan USB'),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6F62), foregroundColor: Colors.white),
                            onPressed: () async {
                              try {
                                await store.savePrinterConfig(
                                  type: _selectedPrinterType,
                                  lanIp: _ipController.text.trim(),
                                  lanPort: _portController.text.trim(),
                                  bluetoothMac: _btMacController.text.trim(),
                                  usbVendorId: _usbVendorController.text.trim(),
                                  usbProductId: _usbProductController.text.trim(),
                                );
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfigurasi Printer Disimpan')));
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Simpan gagal: $e')));
                              }
                            },
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Simpan Konfigurasi'),
                          ),
                          OutlinedButton.icon(
                            onPressed: store.testPrinter,
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Test Print'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...store.discoveredPrinters.map(
                        (candidate) => Card(
                          margin: const EdgeInsets.only(top: 8),
                          color: const Color(0xFFF9FAFA),
                          child: ListTile(
                            dense: true,
                            title: Text(candidate.name),
                            subtitle: Text('${candidate.connectionType.name.toUpperCase()} | ${candidate.address}'),
                            trailing: OutlinedButton(
                              onPressed: () => store.useScannedPrinter(candidate),
                              child: const Text('Pakai'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Kiosk Mode ──
                _sectionCard(
                  title: 'Kiosk / Lock Task Mode',
                  icon: Icons.lock_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: store.kioskActive
                              ? const Color(0xFF1CD485).withOpacity(0.12)
                              : const Color(0xFFF9FAFA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              store.kioskActive ? Icons.lock : Icons.lock_open,
                              size: 16,
                              color: store.kioskActive ? const Color(0xFF1CD485) : const Color(0xFF8E8E99),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              store.kioskSupported
                                  ? (store.kioskActive ? 'AKTIF — tablet terkunci di app' : 'NONAKTIF')
                                  : 'Device tidak mendukung lock task',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: store.kioskActive ? const Color(0xFF1CD485) : const Color(0xFF8E8E99),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6F62), foregroundColor: Colors.white),
                            onPressed: store.kioskSupported && !store.kioskActive ? store.startKioskMode : null,
                            icon: const Icon(Icons.lock, size: 16),
                            label: const Text('Aktifkan Kiosk'),
                          ),
                          OutlinedButton.icon(
                            onPressed: store.kioskSupported && store.kioskActive ? store.stopKioskMode : null,
                            icon: const Icon(Icons.lock_open, size: 16),
                            label: const Text('Matikan Kiosk'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => store.refreshKioskStatus(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Cek Status'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Catatan: untuk produksi, aktifkan Screen Pinning atau Dedicated Device Mode di Android enterprise.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8E8E99)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Mode Display ──
                _sectionCard(
                  title: 'Mode Display',
                  icon: Icons.display_settings_rounded,
                  child: Column(
                    children: [
                      _settingsToggle(
                        title: 'Simulasi Layout Tablet',
                        subtitle: 'Aktifkan ini saat tes di HP agar layout mengikuti mode tablet.',
                        value: store.forceTabletPreview,
                        onChanged: store.setForceTabletPreview,
                      ),
                      const Divider(height: 16),
                      _settingsToggle(
                        title: 'Tablet Production Mode',
                        subtitle: 'Preset tombol lebih besar dan skala teks khusus operasional kasir tablet.',
                        value: store.tabletProductionMode,
                        onChanged: store.setTabletProductionMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Aksi & Logout ──
                _sectionCard(
                  title: 'Aksi Sistem',
                  icon: Icons.miscellaneous_services_rounded,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6F62), foregroundColor: Colors.white),
                        onPressed: store.refreshProducts,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh Produk dari Server'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6F62), foregroundColor: Colors.white),
                        onPressed: () => store.loadDashboard(),
                        icon: const Icon(Icons.dashboard, size: 16),
                        label: const Text('Refresh Dashboard'),
                      ),
                      OutlinedButton.icon(
                        onPressed: store.logout,
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Logout / Ganti Akun'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade400, side: BorderSide(color: Colors.red.shade400)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── App Info ──
                _sectionCard(
                  title: 'Info Aplikasi',
                  icon: Icons.info_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('POS Kevin v1.0.0', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('API: ${AppConfig.apiBaseUrl}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E99))),
                      const SizedBox(height: 2),
                      Text('Outlet ID: ${AppConfig.defaultOutletId}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E99))),
                      const SizedBox(height: 2),
                      Text('Warehouse ID: ${AppConfig.defaultWarehouseId}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E99))),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
