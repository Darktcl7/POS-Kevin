import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:image_picker/image_picker.dart';
import '../state/pos_store.dart';
import '../core/config/app_config.dart';
import '../services/printer_service.dart';
import '../widgets/shared_widgets.dart';
import 'admin/user_management_tab.dart';
import 'admin/ingredient_management_tab.dart';

class AdminView extends StatefulWidget {
  const AdminView({required this.store});

  final PosStore store;

  @override
  State<AdminView> createState() => AdminViewState();
}

class AdminViewState extends State<AdminView> with SingleTickerProviderStateMixin {
  late PrinterConnectionType _selectedPrinterType;
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _btMacController;
  late final TextEditingController _usbVendorController;
  late final TextEditingController _usbProductController;
  late final TextEditingController _historySearchController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kIsWeb ? 6 : 7, vsync: this);
    _selectedPrinterType = widget.store.printerConnectionType;
    _ipController = TextEditingController(text: widget.store.printerLanIp);
    _portController = TextEditingController(text: '${widget.store.printerLanPort}');
    _btMacController = TextEditingController(text: widget.store.printerBluetoothMac);
    _usbVendorController = TextEditingController(text: widget.store.printerUsbVendorId);
    _usbProductController = TextEditingController(text: widget.store.printerUsbProductId);
    _historySearchController = TextEditingController(text: widget.store.saleHistorySearchQuery);

    // Auto-load dashboard data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadDashboard();
      widget.store.refreshProducts(); // Always fetch latest products from server
    });

    // Auto-refresh data when switching tabs
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      switch (_tabController.index) {
        case 2: // Produk
          widget.store.refreshProducts();
          break;
        case 5: // Riwayat Transaksi
          widget.store.refreshSaleHistory();
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _btMacController.dispose();
    _usbVendorController.dispose();
    _usbProductController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final compact = MediaQuery.sizeOf(context).width < 1180;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    const accent = Color(0xFF1E6F62);
    const surface = Color(0xFFFFFFFF);
    const bg = Color(0xFFF4F1E8);

    Color syncStatusColor(String status) {
      switch (status) {
        case 'PENDING':
          return Colors.orange.shade800;
        case 'FAILED_PERMANENT':
          return Colors.red.shade800;
        default:
          return Colors.green.shade800;
      }
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Header Banner ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E6F62), Color(0xFF3aa69b)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Dashboard',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kontrol operasional kasir, penjualan, stok, sync, printer, kiosk, dan audit log.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (store.dashboardLoading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  else
                    IconButton(
                      onPressed: () => store.loadDashboard(),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Refresh Dashboard',
                    ),
                ],
              ),
            ),
          ),

          // ── Tab Bar ──
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF1F2D2E),
              unselectedLabelColor: const Color(0xFF6B7A7B),
              indicatorColor: accent,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: '📊 Dashboard'),
                const Tab(text: '⏳ Tagihan Tempo'),
                const Tab(text: '📦 Produk'),
                const Tab(text: '🧪 Bahan Baku & Stok'),
                const Tab(text: '👥 Kelola User'),
                const Tab(text: '🧾 Riwayat Transaksi'),
                if (!kIsWeb) const Tab(text: '📋 Audit Log'),
              ],
            ),
          ),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(store, formatter, accent, surface),
                _buildTempoTab(store, formatter, surface),
                _buildProductTab(store, formatter, surface),
                IngredientManagementTab(store: store, surfaceColor: surface, formatter: formatter),
                UserManagementTab(store: store, surfaceColor: surface),
                _buildSaleHistoryTab(store, formatter, compact, syncStatusColor),
                if (!kIsWeb) _buildAuditLogTab(store, compact),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ╔══════════════════════╗
  // ║ TAB: TAGIHAN TEMPO   ║
  // ╚══════════════════════╝
  Widget _buildTempoTab(PosStore store, NumberFormat fmt, Color surface) {
    if (store.tempoSales.isEmpty) {
      return const Center(child: Text('Tidak ada tagihan tempo yang belum dibayar.', style: TextStyle(color: Color(0xFF8E8E99))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: store.tempoSales.length,
      itemBuilder: (context, index) {
        final sale = store.tempoSales[index];
        final now = DateTime.now();
        final due = sale.dueDate ?? now;
        final difference = due.difference(now).inDays;
        
        bool isWarning = difference <= 3;
        
        return Card(
          color: surface,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: isWarning ? Colors.red.withOpacity(0.5) : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sale.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8E8E99))),
                      const SizedBox(height: 4),
                      Text(sale.customerName ?? 'Tanpa Nama', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('No WA: ${sale.customerPhone ?? "-"}', style: const TextStyle(color: Color(0xFFBBBBC0))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmt.format(sale.totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E6F62))),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: isWarning ? Colors.red : Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Jatuh Tempo: ${sale.dueDate?.toIso8601String().substring(0, 10)}',
                            style: TextStyle(color: isWarning ? Colors.red : Colors.green, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (isWarning)
                        Text('($difference hari lagi)', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final phone = sale.customerPhone!.startsWith('0') 
                          ? '62${sale.customerPhone!.substring(1)}' 
                          : sale.customerPhone!;
                      final msg = 'Halo Bpk/Ibu ${sale.customerName}, mengingatkan untuk tagihan POS Kevin sebesar ${fmt.format(sale.totalAmount)} yang akan jatuh tempo pada ${sale.dueDate?.toIso8601String().substring(0, 10)}. Mohon segera diselesaikan. Terima kasih.';
                      final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
                      try {
                        await url_launcher.launchUrl(url, mode: url_launcher.LaunchMode.externalApplication);
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tidak bisa membuka WA: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text('Kirim WA', style: TextStyle(color: Colors.white)),
                  )
                else
                  const OutlinedButton(onPressed: null, child: Text('No WA Kosong')),
              ],
            ),
          ),
        );
      },
    );
  }

  // ╔══════════════════════╗
  // ║     TAB: PRODUK CR   ║
  // ╚══════════════════════╝
  Widget _buildProductTab(PosStore store, NumberFormat fmt, Color surface) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Katalog Produk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showProductDialog(store, null),
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E6F62), foregroundColor: Colors.white),
                label: const Text('Tambah Produk'),
              ),
            ],
          ),
        ),
        if (store.adminProductLoading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: store.products.length,
            itemBuilder: (context, index) {
              final product = store.products[index];
              return Card(
                color: surface,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: product.imageUrl != null ? NetworkImage(product.imageUrl!) : null,
                    onBackgroundImageError: (_, __) {},
                    backgroundColor: const Color(0xFF2A2A32),
                    child: product.imageUrl == null ? const Icon(Icons.fastfood, color: Colors.white54) : null,
                  ),
                  title: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${product.categoryName} • Jual: ${fmt.format(product.sellingPrice)} • Modal: ${fmt.format(product.costPrice)} • Margin: ${product.profitMarginPercent.toStringAsFixed(1)}%'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showProductDialog(store, product)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => store.deleteProduct(product.id)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showProductDialog(PosStore store, dynamic product) {
    store.loadAdminCategories();
    
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: isEdit ? product.productName : '');
    final priceCtrl = TextEditingController(text: isEdit ? product.sellingPrice.toString() : '');
    final costPriceCtrl = TextEditingController(text: isEdit ? product.costPrice.toString() : '0');
    final photoCtrl = TextEditingController(text: isEdit ? product.imageUrl ?? '' : '');
    int? selectedCategory;
    if (isEdit) {
      final match = store.adminCategories.where((c) => c['category_name'] == product.categoryName);
      if (match.isNotEmpty) selectedCategory = match.first['id'] as int?;
    }
    
    File? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickImage() async {
            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
            if (pickedFile != null) {
              setModalState(() {
                selectedImage = File(pickedFile.path);
                photoCtrl.text = ''; // Clear URL if local file selected
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFFFFFFF),
            title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  store.adminCategories.isEmpty 
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<int>(
                        value: selectedCategory,
                        items: store.adminCategories.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['category_name'].toString()))).toList(),
                        onChanged: (val) => setModalState(() => selectedCategory = val),
                        decoration: const InputDecoration(labelText: 'Kategori'),
                      ),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Produk')),
                  const SizedBox(height: 12),
                  TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga Jual')),
                  const SizedBox(height: 12),
                  TextField(controller: costPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga Modal (HPP)')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: photoCtrl, decoration: const InputDecoration(labelText: 'URL Foto (Opsional)'))),
                      IconButton(
                        icon: const Icon(Icons.photo_library),
                        onPressed: pickImage,
                        tooltip: 'Pilih dari Galeri',
                      ),
                    ],
                  ),
                  if (selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Image.file(selectedImage!, height: 100, fit: BoxFit.cover),
                    ),
                  if (selectedImage == null && photoCtrl.text.isNotEmpty && photoCtrl.text.startsWith('http'))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Image.network(photoCtrl.text, height: 100, fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCategory == null || nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                  
                  final data = <String, dynamic>{
                    'category_id': selectedCategory,
                    'product_name': nameCtrl.text,
                    'selling_price': double.tryParse(priceCtrl.text) ?? 0,
                    'cost_price': double.tryParse(costPriceCtrl.text) ?? 0,
                    'photo': photoCtrl.text.isEmpty ? null : photoCtrl.text,
                  };

                  if (selectedImage != null) {
                    data['photo_file'] = selectedImage!.path;
                  }

                  bool success = false;
                  if (isEdit) {
                    success = await store.updateProduct(product.id, data);
                  } else {
                    success = await store.createProduct(data);
                  }
                  
                  if (success && context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        }
      ),
    );
  }

  // ╔══════════════════════╗
  // ║   TAB 1: DASHBOARD   ║
  // ╚══════════════════════╝
  Widget _buildDashboardTab(PosStore store, NumberFormat fmt, Color accent, Color surface) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary Metric Cards ──
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            AdminTile(title: 'Transaksi Hari Ini', value: '${store.dashTrxCount}', icon: Icons.receipt_long_rounded, accentColor: accent),
            AdminTile(title: 'Omzet Hari Ini', value: fmt.format(store.dashGrossSales), icon: Icons.trending_up_rounded, accentColor: const Color(0xFF1CD485)),
            AdminTile(title: 'Expense Hari Ini', value: fmt.format(store.dashExpenseTotal), icon: Icons.money_off_rounded, accentColor: Colors.red.shade400),
            AdminTile(title: 'Net Cashflow', value: fmt.format(store.dashNetCashflow), icon: Icons.account_balance_wallet_rounded, accentColor: Colors.blue.shade300),
            AdminTile(title: 'Low Stock Items', value: '${store.dashLowStockCount}', icon: Icons.warning_amber_rounded, accentColor: Colors.orange),
            AdminTile(title: 'Produk Tersimpan', value: '${store.products.length}', icon: Icons.inventory_2_rounded, accentColor: accent),
            AdminTile(title: 'Antrian Sync', value: '${store.pendingSyncCount}', icon: Icons.cloud_sync_rounded, accentColor: Colors.orange),
            AdminTile(title: 'Dead Letter', value: '${store.deadLetterSyncCount}', icon: Icons.error_outline, accentColor: Colors.red.shade400),
          ],
        ),
        const SizedBox(height: 16),

        // ── Sales Trend ──
        _sectionCard(
          title: 'Sales Trend (7 Hari)',
          icon: Icons.show_chart_rounded,
          child: store.dashSalesTrend.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Belum ada data penjualan.', style: TextStyle(color: Color(0xFF8E8E99))),
                )
              : Column(
                  children: store.dashSalesTrend.map((row) {
                    final date = row['sale_date'] ?? '';
                    final trx = row['trx_count'] ?? 0;
                    final gross = (row['gross_sales'] ?? 0).toDouble();
                    final maxGross = store.dashSalesTrend.fold<double>(
                      1,
                      (max, r) => ((r['gross_sales'] ?? 0).toDouble()) > max ? (r['gross_sales'] ?? 0).toDouble() : max,
                    );
                    final pct = (gross / maxGross).clamp(0.03, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 90, child: Text(date.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD3DBDB),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: FractionallySizedBox(
                                widthFactor: pct,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                    gradient: const LinearGradient(colors: [Color(0xFF1E6F62), Color(0xFF3aa69b)]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(width: 50, child: Text('$trx trx', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 8),
                          SizedBox(width: 100, child: Text(fmt.format(gross), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),

        // ── Row: Top Products + Low Stock ──
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 700;
            final children = [
              // Top Products
              _sectionCard(
                title: 'Top Products',
                icon: Icons.emoji_events_rounded,
                child: store.dashTopProducts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Belum ada data.', style: TextStyle(color: Color(0xFF8E8E99))),
                      )
                    : Column(
                        children: store.dashTopProducts.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final row = entry.value;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: idx < 3 ? const Color(0xFF1E6F62) : const Color(0xFFD3DBDB),
                              child: Text('${idx + 1}', style: TextStyle(color: idx < 3 ? Colors.white : const Color(0xFF6B7A7B), fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                            title: Text(row['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            trailing: Text(
                              '${row['total_qty'] ?? 0} pcs  ${fmt.format((row['total_sales'] ?? 0).toDouble())}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
              ),

              // Low Stock
              _sectionCard(
                title: 'Low Stock Alert',
                icon: Icons.inventory_rounded,
                child: store.dashLowStockItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Semua bahan baku aman stoknya.', style: TextStyle(color: Color(0xFF8E8E99))),
                      )
                    : Column(
                        children: store.dashLowStockItems.map((row) {
                          final onHand = (row['on_hand_qty'] ?? 0).toDouble();
                          final minimum = (row['minimum_stock'] ?? 0).toDouble();
                          final isLow = onHand <= minimum;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: isLow ? Colors.orange : const Color(0xFF1CD485),
                              size: 20,
                            ),
                            title: Text(row['ingredient_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text('Gudang: ${row['warehouse_name'] ?? '-'}', style: const TextStyle(fontSize: 11)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${onHand.toStringAsFixed(0)} ${row['unit'] ?? ''}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isLow ? Colors.orange : const Color(0xFF1CD485))),
                                Text('min: ${minimum.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E99))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ];

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 12),
                  Expanded(child: children[1]),
                ],
              );
            }
            return Column(children: [children[0], const SizedBox(height: 12), children[1]]);
          },
        ),
      ],
    );
  }

  // ╔═══════════════════════════════╗
  // ║   TAB 2: RIWAYAT TRANSAKSI   ║
  // ╚═══════════════════════════════╝
  Widget _buildSaleHistoryTab(PosStore store, NumberFormat formatter, bool compact, Color Function(String) syncStatusColor) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filters
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<int>(
                value: store.saleHistoryRangeDays,
                decoration: const InputDecoration(isDense: true, labelText: 'Periode'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 hari')),
                  DropdownMenuItem(value: 7, child: Text('7 hari')),
                  DropdownMenuItem(value: 30, child: Text('30 hari')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  store.setSaleHistoryRangeDays(value);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: store.salesHistoryFromCache ? Colors.orange.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                store.salesHistoryFromCache ? 'CACHE OFFLINE' : 'SERVER',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: store.salesHistoryFromCache ? Colors.orange.shade900 : Colors.green.shade900,
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: store.saleHistoryStatusFilter,
                decoration: const InputDecoration(isDense: true, labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                  DropdownMenuItem(value: 'SYNCED', child: Text('SYNCED')),
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                  DropdownMenuItem(value: 'FAILED_PERMANENT', child: Text('FAILED')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  store.setSaleHistoryStatusFilter(value);
                },
              ),
            ),
            SizedBox(
              width: 230,
              child: TextField(
                controller: _historySearchController,
                onChanged: store.setSaleHistorySearchQuery,
                decoration: const InputDecoration(isDense: true, labelText: 'Cari invoice/produk', prefixIcon: Icon(Icons.search, size: 18)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: store.failedHistoryCount > 0 ? store.retryAllFailedHistoryInvoices : null,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text('Retry FAILED (${store.failedHistoryCount})'),
            ),
            OutlinedButton.icon(
              onPressed: () => store.refreshSaleHistory(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sale list
        if (store.filteredSalesHistory.isEmpty)
          const EmptyStateCard(
            icon: Icons.receipt_long,
            title: 'Belum ada riwayat transaksi',
            subtitle: 'Coba ubah filter tanggal atau lakukan transaksi baru.',
          )
        else
          ...store.filteredSalesHistory.take(30).map(
            (sale) => Card(
              color: const Color(0xFFFFFFFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sale.invoiceNumber,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: syncStatusColor(sale.syncStatus).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sale.syncStatus,
                            style: TextStyle(color: syncStatusColor(sale.syncStatus), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt)} | '
                      '${sale.paymentMethod} | ${sale.details.length} item'
                      '${sale.localOnly ? ' | local queue' : ''}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E99)),
                    ),
                    const SizedBox(height: 4),
                    Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _actionChip(Icons.print, 'Reprint', () => store.reprintSaleByInvoice(sale)),
                        if (sale.localOnly && sale.syncStatus != 'SYNCED')
                          _actionChip(Icons.sync_problem, 'Retry Sync', () => store.retrySyncForInvoice(sale)),
                        _actionChip(Icons.picture_as_pdf, 'PDF', () => store.exportSaleReceiptPdf(sale)),
                        _actionChip(Icons.share, 'Share', () => store.exportSaleReceiptPdf(sale, share: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }


  // ╔══════════════════════╗
  // ║   TAB 4: AUDIT LOG   ║
  // ╚══════════════════════╝
  Widget _buildAuditLogTab(PosStore store, bool compact) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Retry Audit Log ──
        _sectionCard(
          title: 'Retry Audit Log (${store.retryAuditLogTotal})',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<int>(
                      value: store.retryAuditRetentionDays,
                      decoration: const InputDecoration(isDense: true, labelText: 'Retention'),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('7 hari')),
                        DropdownMenuItem(value: 30, child: Text('30 hari')),
                        DropdownMenuItem(value: 90, child: Text('90 hari')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        store.setRetryAuditRetentionDays(value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: store.cleanupRetryAuditLogs,
                    icon: const Icon(Icons.cleaning_services, size: 16),
                    label: const Text('Cleanup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => store.syncRetryAuditLogs(),
                    icon: const Icon(Icons.cloud_upload, size: 16),
                    label: Text('Sync (${store.retryAuditUnsyncedTotal})'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await store.exportRetryAuditLogsCsv();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export gagal: $e')));
                      }
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (store.retryAuditLogs.isEmpty)
                const EmptyStateCard(
                  icon: Icons.fact_check_outlined,
                  title: 'Audit log masih kosong',
                  subtitle: 'Log akan muncul saat kamu melakukan retry sync invoice.',
                )
              else
                ...store.retryAuditLogs.take(30).map(
                  (log) => ListTile(
                    dense: true,
                    leading: Icon(
                      log.status == 'SUCCESS' ? Icons.check_circle : Icons.error_outline,
                      color: log.status == 'SUCCESS' ? const Color(0xFF1CD485) : Colors.red.shade400,
                      size: 20,
                    ),
                    title: Text(
                      '${log.actionType} | ${log.invoiceNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd/MM HH:mm:ss').format(log.createdAt)} | ${log.performedBy} | ${log.resultMessage}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: log.status == 'SUCCESS' ? const Color(0xFF1CD485).withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(log.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: log.status == 'SUCCESS' ? const Color(0xFF1CD485) : Colors.red.shade400)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Void Item Log ──
        _sectionCard(
          title: 'Void Item Log (${store.voidItemUnsyncedTotal} unsynced)',
          icon: Icons.remove_shopping_cart_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: () => store.syncVoidItemLogs(),
                icon: const Icon(Icons.cloud_upload, size: 16),
                label: const Text('Sync Server'),
              ),
              const SizedBox(height: 8),
              if (store.voidItemLogs.isEmpty)
                const EmptyStateCard(
                  icon: Icons.remove_shopping_cart_outlined,
                  title: 'Belum ada void item',
                  subtitle: 'Log void akan muncul saat item dihapus dengan alasan.',
                )
              else
                ...store.voidItemLogs.take(30).map(
                  (log) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange, size: 20),
                    title: Text('${log.productName} x${log.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text(
                      '${DateFormat('dd/MM HH:mm:ss').format(log.createdAt)} | ${log.performedBy}\nAlasan: ${log.reason}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  // ═══════════════════════════════
  //  HELPER WIDGETS
  // ═══════════════════════════════

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E6F62).withValues(alpha: 0.16)),
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
                    color: const Color(0xFF1E6F62).withValues(alpha: 0.1),
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

  Widget _actionChip(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ═══════════════════════════════
//  ADMIN TILE WIDGET
// ═══════════════════════════════
class AdminTile extends StatelessWidget {
  const AdminTile({required this.title, required this.value, this.icon, this.accentColor});

  final String title;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF1E6F62);
    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.7,
                      color: accent.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1f2d2e)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
