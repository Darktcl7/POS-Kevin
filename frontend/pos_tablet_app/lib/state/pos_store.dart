import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/cart_item.dart';
import '../domain/models/held_order.dart';
import '../domain/models/product.dart';
import '../domain/models/retry_audit_log.dart';
import '../domain/models/sale_history_item.dart';
import '../domain/models/sync_queue_item.dart';
import '../domain/models/void_item_log.dart';
import '../services/auth_service.dart';
import '../services/kiosk_service.dart';
import '../services/pos_service.dart';
import '../services/printer_service.dart';
import '../services/sync_service.dart';

class PosStore extends ChangeNotifier {
  PosStore({
    required this.authService,
    required this.posService,
    required this.syncService,
    required this.printerService,
    required this.kioskService,
  });

  final AuthService authService;
  final PosService posService;
  final SyncService syncService;
  final PrinterService printerService;
  final KioskService kioskService;

  List<Product> products = [];
  final List<CartItem> cart = [];

  bool loading = false;
  bool authenticated = false;
  String userRole = 'Kasir';
  bool syncing = false;
  bool checkouting = false;
  bool forceTabletPreview = false;
  bool tabletProductionMode = false;
  bool kioskSupported = false;
  bool kioskActive = false;

  String status = 'Ready';
  String productSearchQuery = '';
  String cashReceivedInput = '';
  String paymentMethod = 'CASH';
  int pendingSyncCount = 0;
  int deadLetterSyncCount = 0;
  List<SyncQueueItem> deadLetterItems = [];
  List<SyncQueueItem> recentSyncItems = [];
  List<SaleHistoryItem> salesHistory = [];
  List<RetryAuditLog> retryAuditLogs = [];
  List<HeldOrder> heldOrders = [];
  List<VoidItemLog> voidItemLogs = [];
  int voidItemUnsyncedTotal = 0;
  int retryAuditLogTotal = 0;
  int retryAuditUnsyncedTotal = 0;
  int retryAuditRetentionDays = 30;
  bool salesHistoryFromCache = false;
  int saleHistoryRangeDays = 7;
  String saleHistoryStatusFilter = 'ALL';
  String saleHistorySearchQuery = '';
  String syncStatusFilter = 'ALL';
  String syncSearchQuery = '';

  // ── Dashboard live data ──
  bool dashboardLoading = false;
  int dashTrxCount = 0;
  double dashGrossSales = 0;
  double dashExpenseTotal = 0;
  double dashNetCashflow = 0;
  int dashLowStockCount = 0;
  List<Map<String, dynamic>> dashSalesTrend = [];
  List<Map<String, dynamic>> dashTopProducts = [];
  List<Map<String, dynamic>> dashLowStockItems = [];

  // ── User Management data ──
  bool usersLoading = false;
  List<Map<String, dynamic>> usersList = [];
  List<Map<String, dynamic>> rolesList = [];
  List<Map<String, dynamic>> outletsList = [];

  // ── Ingredient Management data ──
  bool ingredientsLoading = false;
  List<Map<String, dynamic>> ingredientsList = [];
  List<Map<String, dynamic>> warehousesList = [];
  List<Map<String, dynamic>> suppliersList = [];

  PrinterConnectionType printerConnectionType = PrinterConnectionType.lan;
  String printerLanIp = '';
  int printerLanPort = 9100;
  String printerBluetoothMac = '';
  String printerUsbVendorId = '';
  String printerUsbProductId = '';
  List<PrinterCandidate> discoveredPrinters = [];
  bool scanningPrinters = false;

  Timer? _autoSyncTimer;

  bool get isAdmin => userRole == 'Owner' || userRole == 'Manager';
  bool get isAdminOrGudang => isAdmin || userRole == 'Admin Gudang';

  bool get hasLastReceipt => printerService.hasLastReceipt;
  bool get isCashPayment => paymentMethod == 'CASH';
  double get cashReceivedAmount {
    final normalized = cashReceivedInput.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }
  double get cashChangeAmount => cashReceivedAmount - cartTotal;
  bool get isTempo => paymentMethod == 'TEMPO';
  bool get canCheckout =>
      cart.isNotEmpty && !checkouting && (!isCashPayment || cashReceivedAmount >= cartTotal);
  List<double> get quickCashSuggestions {
    if (cartTotal <= 0) return const [];

    double roundUp(double amount, double step) {
      final n = (amount / step).ceil();
      return n * step;
    }

    final values = <double>{
      cartTotal,
      roundUp(cartTotal, 5000),
      roundUp(cartTotal, 10000),
      roundUp(cartTotal, 50000),
    }.where((v) => v > 0).toList()
      ..sort();

    return values;
  }
  List<Product> get filteredProducts {
    final q = productSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return products;

    return products.where((p) {
      final haystack = '${p.productName} ${p.categoryName}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }
  List<SyncQueueItem> get filteredSyncItems {
    final status = syncStatusFilter.toUpperCase();
    final query = syncSearchQuery.trim().toLowerCase();

    return recentSyncItems.where((item) {
      final statusMatch = status == 'ALL' || item.status.toUpperCase() == status;
      if (!statusMatch) return false;

      if (query.isEmpty) return true;
      final haystack = [
        item.id.toString(),
        item.entityType,
        item.operation,
        item.status,
        item.lastError ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }
  List<SaleHistoryItem> get filteredSalesHistory {
    final status = saleHistoryStatusFilter.toUpperCase();
    final query = saleHistorySearchQuery.trim().toLowerCase();

    return salesHistory.where((item) {
      final statusMatch = status == 'ALL' || item.syncStatus.toUpperCase() == status;
      if (!statusMatch) return false;

      if (query.isEmpty) return true;
      final haystack = [
        item.invoiceNumber,
        item.paymentMethod,
        item.orderType,
        item.syncStatus,
        ...item.details.map((e) => e.productName),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
  int get failedHistoryCount =>
      salesHistory.where((item) => item.localOnly && item.syncStatus == 'FAILED_PERMANENT').length;

  // ── User Management Fetch ──
  Future<void> loadUsers() async {
    usersLoading = true;
    notifyListeners();
    try {
      final res = await posService.getUsers();
      usersList = List<Map<String, dynamic>>.from(res['users'] ?? []);
      rolesList = List<Map<String, dynamic>>.from(res['roles'] ?? []);
      outletsList = List<Map<String, dynamic>>.from(res['outlets'] ?? []);
      status = 'Users loaded';
    } catch(e) {
      status = 'Gagal memuat users: $e';
    }
    usersLoading = false;
    notifyListeners();
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    try {
      await posService.createUser(data);
      await loadUsers();
      status = 'User berhasil ditambahkan';
    } catch(e) {
      status = 'Gagal menambah user: $e';
    }
    notifyListeners();
  }

  Future<void> toggleUserActive(int id) async {
    try {
      await posService.toggleUserActive(id);
      await loadUsers();
      status = 'Status user diubah';
    } catch(e) {
      status = 'Gagal mengubah status: $e';
    }
    notifyListeners();
  }

  Future<void> resetUserPassword(int id, String newPassword) async {
    try {
      await posService.resetUserPassword(id, newPassword);
      status = 'Password user berhasil direset';
    } catch(e) {
      status = 'Gagal reset password: $e';
    }
    notifyListeners();
  }

  Future<void> deleteUser(int id) async {
    try {
      await posService.deleteUser(id);
      await loadUsers();
      status = 'User berhasil dihapus';
    } catch(e) {
      status = 'Gagal menghapus user: $e';
    }
    notifyListeners();
  }

  // ── Ingredient Management ──
  Future<void> loadIngredients() async {
    ingredientsLoading = true;
    notifyListeners();
    try {
      final res = await posService.getIngredients();
      ingredientsList = List<Map<String, dynamic>>.from(res['ingredients'] ?? []);
      warehousesList = List<Map<String, dynamic>>.from(res['warehouses'] ?? []);
      suppliersList = List<Map<String, dynamic>>.from(res['suppliers'] ?? []);
      status = 'Bahan baku loaded';
    } catch(e) {
      status = 'Gagal memuat bahan baku: $e';
    }
    ingredientsLoading = false;
    notifyListeners();
  }

  Future<void> createIngredient(Map<String, dynamic> data) async {
    try {
      await posService.createIngredient(data);
      await loadIngredients();
      status = 'Bahan baku berhasil ditambahkan';
    } catch(e) {
      status = 'Gagal menambah bahan baku: $e';
    }
    notifyListeners();
  }

  Future<void> updateIngredientStock(int id, Map<String, dynamic> data) async {
    try {
      await posService.updateIngredientStock(id, data);
      await loadIngredients();
      status = 'Stok berhasil diperbarui';
    } catch(e) {
      status = 'Gagal update stok: $e';
    }
    notifyListeners();
  }

  Future<void> deleteIngredient(int id) async {
    try {
      await posService.deleteIngredient(id);
      await loadIngredients();
      status = 'Bahan baku terhapus';
    } catch(e) {
      status = 'Gagal menghapus bahan baku: $e';
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    notifyListeners();

    authenticated = await authService.restoreSession();
    if (authenticated) {
      userRole = await authService.currentUserRole();
    }
    await _loadUiPreferences();

    if (authenticated) {
      await _loadPosData();
      await _loadPrinterConfig();
      _startAutoSync();
    } else {
      status = 'Silakan login';
    }
    await refreshKioskStatus(silent: true);

    loading = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    loading = true;
    status = 'Login...';
    notifyListeners();

    try {
      await authService.login(email: email, password: password, deviceName: 'POS_TABLET_ANDROID');
      authenticated = true;
      userRole = await authService.currentUserRole();
      await _loadPosData();
      await _loadPrinterConfig();
      await syncRetryAuditLogs(silent: true);
      await syncVoidItemLogs(silent: true);
      _startAutoSync();
      status = 'Login berhasil';
    } catch (e) {
      authenticated = false;
      status = 'Login gagal: $e';
    }

    loading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    loading = true;
    notifyListeners();

    _autoSyncTimer?.cancel();
    await authService.logout();

    authenticated = false;
    userRole = 'Kasir';
    cart.clear();
    products = [];
    pendingSyncCount = 0;
    deadLetterSyncCount = 0;
    deadLetterItems = [];
    recentSyncItems = [];
    discoveredPrinters = [];
    salesHistory = [];
    retryAuditLogs = [];
    heldOrders = [];
    voidItemLogs = [];
    voidItemUnsyncedTotal = 0;
    retryAuditLogTotal = 0;
    retryAuditUnsyncedTotal = 0;
    retryAuditRetentionDays = 30;
    productSearchQuery = '';
    cashReceivedInput = '';
    paymentMethod = 'CASH';
    forceTabletPreview = false;
    tabletProductionMode = false;
    salesHistoryFromCache = false;
    saleHistoryRangeDays = 7;
    saleHistoryStatusFilter = 'ALL';
    saleHistorySearchQuery = '';
    status = 'Logged out';

    loading = false;
    notifyListeners();
  }


  void addToCart(Product product) {
    final index = cart.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      cart[index].quantity += 1;
    } else {
      cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    cart.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    if (cart.isEmpty) {
      status = 'Keranjang sudah kosong';
      notifyListeners();
      return;
    }
    cart.clear();
    cashReceivedInput = '';
    paymentMethod = 'CASH';
    status = 'Keranjang dikosongkan';
    notifyListeners();
  }

  Future<void> removeFromCartWithReason(int productId, String reason) async {
    final idx = cart.indexWhere((item) => item.product.id == productId);
    if (idx < 0) return;
    final item = cart[idx];
    cart.removeAt(idx);

    final performedBy = await authService.currentUserEmail();
    await authService.database.insertVoidItemLog(
      productName: item.product.productName,
      quantity: item.quantity,
      reason: reason.trim().isEmpty ? 'Tanpa alasan' : reason.trim(),
      performedBy: performedBy,
    );
    await _loadVoidItemLogs();
    await syncVoidItemLogs(silent: true);
    status = 'Item dihapus dari keranjang (void)';
    notifyListeners();
  }

  void increaseCartQty(int productId) {
    final idx = cart.indexWhere((item) => item.product.id == productId);
    if (idx < 0) return;
    cart[idx].quantity += 1;
    notifyListeners();
  }

  void decreaseCartQty(int productId) {
    final idx = cart.indexWhere((item) => item.product.id == productId);
    if (idx < 0) return;

    if (cart[idx].quantity <= 1) {
      cart.removeAt(idx);
    } else {
      cart[idx].quantity -= 1;
    }
    notifyListeners();
  }

  void setProductSearchQuery(String value) {
    productSearchQuery = value;
    notifyListeners();
  }

  void setCashReceivedInput(String value) {
    cashReceivedInput = value;
    notifyListeners();
  }

  void setCashReceivedAmount(double value) {
    cashReceivedInput = value.toStringAsFixed(0);
    notifyListeners();
  }

  void setPaymentMethod(String value) {
    paymentMethod = value;
    if (!isCashPayment) {
      cashReceivedInput = '';
    }
    notifyListeners();
  }

  Future<void> holdCurrentOrder({String? label}) async {
    if (cart.isEmpty) {
      status = 'Keranjang kosong, tidak ada order untuk di-hold.';
      notifyListeners();
      return;
    }

    final hold = HeldOrder(
      id: const Uuid().v4(),
      label: (label?.trim().isNotEmpty == true)
          ? label!.trim()
          : 'Order ${DateFormat('HH:mm:ss').format(DateTime.now())}',
      createdAt: DateTime.now(),
      items: cart
          .map((item) => HeldOrderItem(productId: item.product.id, quantity: item.quantity))
          .toList(),
    );

    heldOrders = [hold, ...heldOrders].take(30).toList();
    cart.clear();
    cashReceivedInput = '';
    paymentMethod = 'CASH';
    await _saveHeldOrders();
    status = 'Order berhasil di-hold';
    notifyListeners();
  }

  Future<void> resumeHeldOrder(String heldId) async {
    final idx = heldOrders.indexWhere((h) => h.id == heldId);
    if (idx < 0) return;
    if (cart.isNotEmpty) {
      status = 'Kosongkan atau hold keranjang saat ini dulu sebelum resume.';
      notifyListeners();
      return;
    }

    final held = heldOrders[idx];
    final rebuilt = <CartItem>[];
    for (final hItem in held.items) {
      Product? product;
      for (final p in products) {
        if (p.id == hItem.productId) {
          product = p;
          break;
        }
      }
      if (product == null) continue;
      rebuilt.add(CartItem(product: product, quantity: hItem.quantity));
    }

    if (rebuilt.isEmpty) {
      status = 'Order hold tidak bisa direstore (produk tidak tersedia).';
      notifyListeners();
      return;
    }

    cart
      ..clear()
      ..addAll(rebuilt);
    heldOrders.removeAt(idx);
    await _saveHeldOrders();
    status = 'Order hold berhasil di-resume';
    notifyListeners();
  }

  Future<void> deleteHeldOrder(String heldId) async {
    heldOrders.removeWhere((h) => h.id == heldId);
    await _saveHeldOrders();
    status = 'Order hold dihapus';
    notifyListeners();
  }

  double get cartTotal => cart.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> refreshProducts() async {
    try {
      products = await posService.refreshProducts();
      status = 'Products updated';
    } catch (e) {
      status = 'Refresh gagal: $e';
    }
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    dashboardLoading = true;
    notifyListeners();
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);

      final results = await Future.wait([
        posService.getDashboardSummary(today),
        posService.getDashboardTrend(7),
        posService.getDashboardTopProducts(sevenDaysAgo, today, 10),
        posService.getDashboardLowStock(20),
      ]);

      final summary = results[0];
      dashTrxCount = (summary['sales_transaction_count'] ?? 0) as int;
      dashGrossSales = (summary['gross_sales'] ?? 0).toDouble();
      dashExpenseTotal = (summary['expense_total'] ?? 0).toDouble();
      dashNetCashflow = (summary['net_cashflow'] ?? 0).toDouble();
      dashLowStockCount = (summary['low_stock_items'] ?? 0) as int;

      final trend = results[1];
      dashSalesTrend = List<Map<String, dynamic>>.from(trend['items'] ?? []);

      final top = results[2];
      dashTopProducts = List<Map<String, dynamic>>.from(top['items'] ?? []);

      final lowStock = results[3];
      dashLowStockItems = List<Map<String, dynamic>>.from(lowStock['items'] ?? []);

      try {
        tempoSales = await posService.fetchTempoSales();
      } catch (_) {}

      pendingSyncCount = await posService.pendingCount();
      deadLetterSyncCount = await posService.deadLetterCount();

      status = 'Dashboard loaded';
    } catch (e) {
      status = 'Dashboard gagal: $e';
    }
    dashboardLoading = false;
    notifyListeners();
  }

  Future<void> checkout({
    String? customerName,
    String? customerPhone,
    DateTime? dueDate,
  }) async {
    if (cart.isEmpty || checkouting) return;
    if (isCashPayment && cashReceivedAmount < cartTotal) {
      status = 'Nominal tunai kurang dari total belanja.';
      notifyListeners();
      return;
    }
    checkouting = true;
    notifyListeners();

    try {
      final invoice = await posService.submitSale(
        cart: List.from(cart), 
        paymentMethod: paymentMethod,
        customerName: customerName,
        customerPhone: customerPhone,
        dueDate: dueDate,
      );
      final total = cartTotal;
      final cashReceived = isCashPayment ? cashReceivedAmount : total;
      final change = isCashPayment ? (cashReceived - total) : 0;
      final lines = cart.map((item) => '${item.product.productName} x${item.quantity}').toList();
      lines.add('----------------');
      lines.add('Metode: $paymentMethod');
      if (isCashPayment) {
        lines.add('Tunai : Rp ${cashReceived.toStringAsFixed(0)}');
        lines.add('Kembali: Rp ${change.toStringAsFixed(0)}');
      }
      var printInfo = '';
      try {
        await printerService.printReceipt(invoiceNumber: invoice, total: total, lines: lines);
      } catch (e) {
        printInfo = ' (print gagal: $e)';
      }

      cart.clear();
      cashReceivedInput = '';
      paymentMethod = 'CASH';
      pendingSyncCount = await posService.pendingCount();
      deadLetterSyncCount = await posService.deadLetterCount();
      deadLetterItems = await posService.deadLetterItems();
      recentSyncItems = await posService.recentSyncItems();
      await refreshSaleHistory(silent: true);
      status = 'Transaksi tersimpan$printInfo';
    } catch (e) {
      status = 'Checkout gagal: $e';
    }

    checkouting = false;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (syncing) return;

    syncing = true;
    notifyListeners();

    try {
      final count = await syncService.syncPending();
      await syncRetryAuditLogs(silent: true);
      await syncVoidItemLogs(silent: true);
      pendingSyncCount = await posService.pendingCount();
      deadLetterSyncCount = await posService.deadLetterCount();
      deadLetterItems = await posService.deadLetterItems();
      recentSyncItems = await posService.recentSyncItems();
      status = count > 0 ? 'Sync sukses: $count data' : 'Tidak ada data yang perlu di-sync saat ini';
    } catch (e) {
      status = 'Sync gagal: $e';
    }

    syncing = false;
    notifyListeners();
  }

  Future<void> savePrinterConfig({
    required PrinterConnectionType type,
    required String lanIp,
    required String lanPort,
    required String bluetoothMac,
    required String usbVendorId,
    required String usbProductId,
  }) async {
    final parsedLanPort = int.tryParse(lanPort);
    if (type == PrinterConnectionType.lan) {
      if (lanIp.trim().isEmpty) {
        throw Exception('IP printer LAN wajib diisi.');
      }
      if (parsedLanPort == null || parsedLanPort <= 0 || parsedLanPort > 65535) {
        throw Exception('Port printer tidak valid.');
      }
    }

    await printerService.saveConfig(
      type: type,
      lanIp: lanIp,
      lanPort: parsedLanPort ?? 9100,
      bluetoothMac: bluetoothMac,
      usbVendorId: usbVendorId,
      usbProductId: usbProductId,
    );

    await _loadPrinterConfig();
    status = 'Konfigurasi printer tersimpan';
    notifyListeners();
  }

  Future<void> testPrinter() async {
    try {
      final result = await printerService.testPrint();
      status = result;
    } catch (e) {
      status = 'Test print gagal: $e';
    }
    notifyListeners();
  }

  Future<void> reprintLastReceipt() async {
    try {
      final result = await printerService.reprintLastReceipt();
      status = result;
    } catch (e) {
      status = 'Reprint gagal: $e';
    }
    notifyListeners();
  }

  Future<void> refreshSaleHistory({bool silent = false}) async {
    final to = DateTime.now();
    final from = DateTime(to.year, to.month, to.day).subtract(Duration(days: saleHistoryRangeDays - 1));

    try {
      final result = await posService.fetchSaleHistory(limit: 40, from: from, to: to);
      salesHistory = result.items;
      salesHistoryFromCache = result.fromCache;
      if (!silent) {
        status = salesHistoryFromCache
            ? 'Riwayat offline cache ($saleHistoryRangeDays hari)'
            : 'Riwayat transaksi diperbarui ($saleHistoryRangeDays hari)';
      }
    } catch (e) {
      if (!silent) {
        status = 'Load riwayat gagal: $e';
      }
    }
    notifyListeners();
  }

  Future<void> setSaleHistoryRangeDays(int days) async {
    saleHistoryRangeDays = days;
    await refreshSaleHistory(silent: true);
    status = 'Filter riwayat $saleHistoryRangeDays hari';
    notifyListeners();
  }

  void setSaleHistoryStatusFilter(String value) {
    saleHistoryStatusFilter = value;
    notifyListeners();
  }

  void setSaleHistorySearchQuery(String value) {
    saleHistorySearchQuery = value;
    notifyListeners();
  }

  Future<void> reprintSaleByInvoice(SaleHistoryItem sale) async {
    final lines = sale.details.map((line) => '${line.productName} x${line.quantity}').toList();

    try {
      final result = await printerService.printReceipt(
        invoiceNumber: sale.invoiceNumber,
        total: sale.totalAmount,
        lines: lines,
      );
      status = 'Reprint ${sale.invoiceNumber} berhasil ($result)';
    } catch (e) {
      status = 'Reprint ${sale.invoiceNumber} gagal: $e';
    }
    notifyListeners();
  }

  Future<void> retrySyncForInvoice(SaleHistoryItem sale) async {
    if (!sale.localOnly) {
      status = 'Invoice server sudah sync, tidak perlu retry.';
      notifyListeners();
      return;
    }

    final queueId = sale.id < 0 ? -sale.id : 0;
    if (queueId <= 0) {
      status = 'Queue id invoice tidak valid.';
      notifyListeners();
      return;
    }

    try {
      if (sale.syncStatus == 'FAILED_PERMANENT') {
        await posService.requeueDeadLetterItem(queueId);
      }
      await syncNow();
      await refreshSaleHistory(silent: true);
      await _logRetryAudit(
        actionType: 'RETRY_SINGLE',
        invoiceNumber: sale.invoiceNumber,
        queueId: queueId,
        status: 'SUCCESS',
        resultMessage: 'Invoice diproses ulang ke sync queue.',
      );
      await _loadRetryAuditLogs();
      await syncRetryAuditLogs(silent: true);
      status = 'Retry sync ${sale.invoiceNumber} diproses';
    } catch (e) {
      await _logRetryAudit(
        actionType: 'RETRY_SINGLE',
        invoiceNumber: sale.invoiceNumber,
        queueId: queueId,
        status: 'FAILED',
        resultMessage: e.toString(),
      );
      await _loadRetryAuditLogs();
      await syncRetryAuditLogs(silent: true);
      status = 'Retry sync ${sale.invoiceNumber} gagal: $e';
    }
    notifyListeners();
  }

  Future<void> retryAllFailedHistoryInvoices() async {
    final failedCount = failedHistoryCount;
    if (failedCount == 0) {
      status = 'Tidak ada invoice FAILED untuk di-retry.';
      notifyListeners();
      return;
    }

    try {
      final moved = await posService.requeueAllDeadLetters();
      await syncNow();
      await refreshSaleHistory(silent: true);
      await _logRetryAudit(
        actionType: 'RETRY_BULK',
        invoiceNumber: 'BULK_FAILED',
        queueId: null,
        status: 'SUCCESS',
        resultMessage: '$moved invoice dipindah ke antrean sync.',
      );
      await _loadRetryAuditLogs();
      await syncRetryAuditLogs(silent: true);
      status = 'Retry bulk diproses: $moved invoice dipindah ke antrean sync';
    } catch (e) {
      await _logRetryAudit(
        actionType: 'RETRY_BULK',
        invoiceNumber: 'BULK_FAILED',
        queueId: null,
        status: 'FAILED',
        resultMessage: e.toString(),
      );
      await _loadRetryAuditLogs();
      await syncRetryAuditLogs(silent: true);
      status = 'Retry bulk gagal: $e';
    }
    notifyListeners();
  }

  Future<void> refreshKioskStatus({bool silent = false}) async {
    try {
      kioskSupported = await kioskService.isSupported();
      kioskActive = kioskSupported ? await kioskService.isActive() : false;
      if (!silent) {
        status = kioskSupported
            ? (kioskActive ? 'Kiosk mode aktif' : 'Kiosk mode standby')
            : 'Kiosk mode tidak didukung device ini';
      }
    } catch (e) {
      if (!silent) {
        status = 'Cek kiosk mode gagal: $e';
      }
    }
    notifyListeners();
  }

  void setForceTabletPreview(bool value) {
    forceTabletPreview = value;
    status = value ? 'Simulasi layout tablet aktif' : 'Simulasi layout tablet nonaktif';
    authService.database.setSetting('ui_force_tablet_preview', value ? '1' : '0');
    notifyListeners();
  }

  void setTabletProductionMode(bool value) {
    tabletProductionMode = value;
    if (value) {
      forceTabletPreview = true;
    }
    status = value ? 'Tablet production mode aktif' : 'Tablet production mode nonaktif';
    authService.database.setSetting('ui_tablet_production_mode', value ? '1' : '0');
    authService.database.setSetting('ui_force_tablet_preview', forceTabletPreview ? '1' : '0');
    notifyListeners();
  }

  Future<void> startKioskMode() async {
    try {
      final ok = await kioskService.start();
      await refreshKioskStatus(silent: true);
      status = ok ? 'Kiosk mode diaktifkan' : 'Gagal aktifkan kiosk mode';
    } catch (e) {
      status = 'Start kiosk gagal: $e';
    }
    notifyListeners();
  }

  Future<void> stopKioskMode() async {
    try {
      final ok = await kioskService.stop();
      await refreshKioskStatus(silent: true);
      status = ok ? 'Kiosk mode dinonaktifkan' : 'Gagal nonaktifkan kiosk mode';
    } catch (e) {
      status = 'Stop kiosk gagal: $e';
    }
    notifyListeners();
  }

  Future<String> exportSaleReceiptPdf(SaleHistoryItem sale, {bool share = false}) async {
    final document = PdfDocument();
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final created = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
    final page = document.pages.add();
    final g = page.graphics;
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final regularFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    var y = 12.0;

    g.drawString('POS KEVIN', titleFont, bounds: Rect.fromLTWH(10, y, 250, 20));
    y += 18;
    g.drawString('Coffee Shop', regularFont, bounds: Rect.fromLTWH(10, y, 250, 20));
    y += 18;
    g.drawString('Invoice: ${sale.invoiceNumber}', regularFont, bounds: Rect.fromLTWH(10, y, 300, 20));
    y += 14;
    g.drawString('Waktu : $created', regularFont, bounds: Rect.fromLTWH(10, y, 300, 20));
    y += 14;
    g.drawString('Bayar : ${sale.paymentMethod}', regularFont, bounds: Rect.fromLTWH(10, y, 300, 20));
    y += 14;
    g.drawString('Sync  : ${sale.syncStatus}', regularFont, bounds: Rect.fromLTWH(10, y, 300, 20));
    y += 14;
    g.drawLine(PdfPen(PdfColor(120, 120, 120)), Offset(10, y), Offset(280, y));
    y += 10;

    for (final line in sale.details) {
      g.drawString('${line.productName} x${line.quantity}', regularFont, bounds: Rect.fromLTWH(10, y, 170, 18));
      g.drawString(currency.format(line.subtotal), regularFont, bounds: Rect.fromLTWH(180, y, 100, 18));
      y += 14;
      if (y > 380) {
        break;
      }
    }

    y += 6;
    g.drawLine(PdfPen(PdfColor(120, 120, 120)), Offset(10, y), Offset(280, y));
    y += 10;
    g.drawString(
      'TOTAL: ${currency.format(sale.totalAmount)}',
      boldFont,
      bounds: Rect.fromLTWH(120, y, 160, 20),
    );

    final directory = await getApplicationDocumentsDirectory();
    final sanitizedInvoice = sale.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${directory.path}/receipt-$sanitizedInvoice.pdf');
    final bytes = await document.save();
    document.dispose();
    await file.writeAsBytes(bytes, flush: true);

    if (share) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Struk ${sale.invoiceNumber}',
      );
    }

    status = share ? 'PDF dibagikan: ${file.path}' : 'PDF disimpan: ${file.path}';
    notifyListeners();
    return file.path;
  }

  Future<void> scanBluetoothPrinters() async {
    await _scanPrinters(PrinterConnectionType.bluetooth);
  }

  Future<void> scanUsbPrinters() async {
    await _scanPrinters(PrinterConnectionType.usb);
  }

  void useScannedPrinter(PrinterCandidate candidate) {
    if (candidate.connectionType == PrinterConnectionType.bluetooth) {
      printerBluetoothMac = candidate.address;
      printerConnectionType = PrinterConnectionType.bluetooth;
      status = 'Printer Bluetooth dipilih: ${candidate.name}';
    } else if (candidate.connectionType == PrinterConnectionType.usb) {
      printerUsbVendorId = candidate.vendorId ?? '';
      printerUsbProductId = candidate.productId ?? '';
      printerConnectionType = PrinterConnectionType.usb;
      status = 'Printer USB dipilih: ${candidate.name}';
    }
    notifyListeners();
  }

  void setSyncStatusFilter(String statusValue) {
    syncStatusFilter = statusValue;
    notifyListeners();
  }

  void setSyncSearchQuery(String query) {
    syncSearchQuery = query;
    notifyListeners();
  }

  Future<String> exportFilteredSyncLogsCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/sync-logs-$ts.csv');

    final rows = <String>[
      'id,entity_type,operation,status,retry_count,created_at,next_retry_at,synced_at,last_error',
    ];

    for (final item in filteredSyncItems) {
      rows.add([
        item.id.toString(),
        _csvEscape(item.entityType),
        _csvEscape(item.operation),
        _csvEscape(item.status),
        item.retryCount.toString(),
        _csvEscape(item.createdAt.toIso8601String()),
        _csvEscape(item.nextRetryAt.toIso8601String()),
        _csvEscape(item.syncedAt?.toIso8601String() ?? ''),
        _csvEscape(item.lastError ?? ''),
      ].join(','));
    }

    await file.writeAsString(rows.join('\n'));
    status = 'Export log berhasil: ${file.path}';
    notifyListeners();
    return file.path;
  }

  Future<void> _loadPosData() async {
    if (kIsWeb) {
      await refreshProducts();
      await refreshSaleHistory(silent: true);
      return;
    }
    products = await posService.loadProducts();
    pendingSyncCount = await posService.pendingCount();
    deadLetterSyncCount = await posService.deadLetterCount();
    deadLetterItems = await posService.deadLetterItems();
    recentSyncItems = await posService.recentSyncItems();
    await refreshSaleHistory(silent: true);
    await _loadRetryAuditLogs();
    await _loadHeldOrders();
    await _loadVoidItemLogs();
    await syncRetryAuditLogs(silent: true);
    await syncVoidItemLogs(silent: true);
  }

  Future<void> _loadUiPreferences() async {
    final force = await authService.database.getSetting('ui_force_tablet_preview');
    final production = await authService.database.getSetting('ui_tablet_production_mode');
    forceTabletPreview = force == '1';
    tabletProductionMode = production == '1';
    if (tabletProductionMode) {
      forceTabletPreview = true;
    }
  }

  Future<void> _loadRetryAuditLogs() async {
    retryAuditLogs = await authService.database.recentRetryAuditLogs(limit: 40);
    retryAuditLogTotal = await authService.database.retryAuditLogCount();
    retryAuditUnsyncedTotal = await authService.database.unsyncedRetryAuditLogCount();
  }

  Future<void> _loadHeldOrders() async {
    final raw = await authService.database.getSetting('held_orders_json');
    if (raw == null || raw.isEmpty) {
      heldOrders = [];
      return;
    }

    try {
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .map((e) => HeldOrder.fromMap(e as Map<String, dynamic>))
          .toList();
      heldOrders = decoded;
    } catch (_) {
      heldOrders = [];
    }
  }

  Future<void> _saveHeldOrders() async {
    final raw = jsonEncode(heldOrders.map((e) => e.toMap()).toList());
    await authService.database.setSetting('held_orders_json', raw);
  }

  Future<void> _loadVoidItemLogs() async {
    voidItemLogs = await authService.database.recentVoidItemLogs(limit: 30);
    voidItemUnsyncedTotal = await authService.database.unsyncedVoidItemLogCount();
  }

  Future<void> _logRetryAudit({
    required String actionType,
    required String invoiceNumber,
    required int? queueId,
    required String status,
    required String resultMessage,
  }) async {
    final performedBy = await authService.currentUserEmail();
    await authService.database.insertRetryAuditLog(
      actionType: actionType,
      invoiceNumber: invoiceNumber,
      queueId: queueId,
      status: status,
      resultMessage: resultMessage,
      performedBy: performedBy,
    );
  }

  Future<void> setRetryAuditRetentionDays(int days) async {
    if (days < 1) return;
    retryAuditRetentionDays = days;
    status = 'Retention audit log: $retryAuditRetentionDays hari';
    notifyListeners();
  }

  Future<void> cleanupRetryAuditLogs() async {
    try {
      final deleted = await authService.database.pruneRetryAuditLogs(keepDays: retryAuditRetentionDays);
      await _loadRetryAuditLogs();
      status = 'Cleanup audit log selesai: $deleted data dihapus';
    } catch (e) {
      status = 'Cleanup audit log gagal: $e';
    }
    notifyListeners();
  }

  Future<void> syncRetryAuditLogs({bool silent = false}) async {
    if (kIsWeb) return;
    try {
      final deviceId = await _resolveDeviceId();
      final synced = await syncService.syncRetryAuditLogs(deviceId: deviceId);
      await _loadRetryAuditLogs();
      if (!silent && synced > 0) {
        status = 'Sync audit log berhasil: $synced item';
      }
      notifyListeners();
    } catch (e) {
      if (!silent) {
        status = 'Sync audit log gagal: $e';
      }
      notifyListeners();
    }
  }

  Future<void> syncVoidItemLogs({bool silent = false}) async {
    if (kIsWeb) return;
    try {
      final deviceId = await _resolveDeviceId();
      final synced = await syncService.syncVoidItemLogs(deviceId: deviceId);
      await _loadVoidItemLogs();
      if (!silent && synced > 0) {
        status = 'Sync void log berhasil: $synced item';
      }
      notifyListeners();
    } catch (e) {
      if (!silent) {
        status = 'Sync void log gagal: $e';
      }
      notifyListeners();
    }
  }

  Future<String> exportRetryAuditLogsCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/retry-audit-logs-$ts.csv');

    final rows = <String>[
      'id,action_type,invoice_number,queue_id,status,result_message,performed_by,created_at',
    ];

    for (final log in retryAuditLogs) {
      rows.add([
        log.id.toString(),
        _csvEscape(log.actionType),
        _csvEscape(log.invoiceNumber),
        _csvEscape(log.queueId?.toString() ?? ''),
        _csvEscape(log.status),
        _csvEscape(log.resultMessage),
        _csvEscape(log.performedBy),
        _csvEscape(log.createdAt.toIso8601String()),
      ].join(','));
    }

    await file.writeAsString(rows.join('\n'));
    status = 'Export audit log berhasil: ${file.path}';
    notifyListeners();
    return file.path;
  }

  Future<void> retryDeadLetterItem(int id) async {
    await posService.requeueDeadLetterItem(id);
    pendingSyncCount = await posService.pendingCount();
    deadLetterSyncCount = await posService.deadLetterCount();
    deadLetterItems = await posService.deadLetterItems();
    recentSyncItems = await posService.recentSyncItems();
    status = '1 dead-letter dipindah ke antrean sync';
    notifyListeners();
  }

  Future<void> retryAllDeadLetters() async {
    final moved = await posService.requeueAllDeadLetters();
    pendingSyncCount = await posService.pendingCount();
    deadLetterSyncCount = await posService.deadLetterCount();
    deadLetterItems = await posService.deadLetterItems();
    recentSyncItems = await posService.recentSyncItems();
    status = '$moved dead-letter dipindah ke antrean sync';
    notifyListeners();
  }

  Future<void> _loadPrinterConfig() async {
    if (kIsWeb) return;
    await printerService.loadConfig();
    printerConnectionType = printerService.connectionType;
    printerLanIp = printerService.lanIp;
    printerLanPort = printerService.lanPort;
    printerBluetoothMac = printerService.bluetoothMac;
    printerUsbVendorId = printerService.usbVendorId;
    printerUsbProductId = printerService.usbProductId;
  }

  Future<void> _scanPrinters(PrinterConnectionType type) async {
    if (scanningPrinters) return;

    final granted = await _ensureScanPermissions(type);
    if (!granted) {
      status = 'Izin scan printer ditolak. Aktifkan izin Bluetooth/Location di Settings.';
      notifyListeners();
      return;
    }

    scanningPrinters = true;
    status = 'Scan printer...';
    notifyListeners();

    try {
      discoveredPrinters = await printerService.scanPrinters(type);
      status = 'Scan selesai: ${discoveredPrinters.length} device ditemukan';
    } catch (e) {
      status = 'Scan printer gagal: $e';
    }

    scanningPrinters = false;
    notifyListeners();
  }

  Future<bool> _ensureScanPermissions(PrinterConnectionType type) async {
    if (!Platform.isAndroid) return true;
    if (type == PrinterConnectionType.lan) return true;

    final permissions = <Permission>[];
    if (type == PrinterConnectionType.bluetooth) {
      permissions.add(Permission.bluetoothScan);
      permissions.add(Permission.bluetoothConnect);
      permissions.add(Permission.locationWhenInUse);
    }

    if (permissions.isEmpty) return true;

    final statuses = await permissions.request();
    for (final permission in permissions) {
      final status = statuses[permission];
      if (status == null || !status.isGranted) {
        return false;
      }
    }

    return true;
  }

  void _startAutoSync() {
    if (kIsWeb) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!authenticated || syncing) return;
      await syncNow();
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<String> _resolveDeviceId() async {
    const key = 'sync_device_id';
    final existing = await authService.database.getSetting(key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = const Uuid().v4();
    await authService.database.setSetting(key, generated);
    return generated;
  }

  // --- Admin Product CRUD ---
  bool adminProductLoading = false;
  List<Map<String, dynamic>> adminCategories = [];
  List<SaleHistoryItem> tempoSales = [];

  Future<void> loadAdminCategories() async {
    try {
      adminCategories = await posService.getCategories();
      notifyListeners();
    } catch (e) {
      status = 'Gagal load kategori: $e';
    }
  }

  Future<bool> createProduct(Map<String, dynamic> data) async {
    adminProductLoading = true;
    notifyListeners();
    try {
      await posService.createProduct(data);
      await refreshProducts(); // Refresh local list
      status = 'Produk berhasil ditambahkan';
      adminProductLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      status = 'Gagal tambah produk: $e';
      adminProductLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    adminProductLoading = true;
    notifyListeners();
    try {
      await posService.updateProduct(id, data);
      await refreshProducts();
      status = 'Produk berhasil diupdate';
      adminProductLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      status = 'Gagal update produk: $e';
      adminProductLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    adminProductLoading = true;
    notifyListeners();
    try {
      await posService.deleteProduct(id);
      await refreshProducts();
      status = 'Produk berhasil dihapus';
      adminProductLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      status = 'Gagal hapus produk: $e';
      adminProductLoading = false;
      notifyListeners();
      return false;
    }
  }
}

