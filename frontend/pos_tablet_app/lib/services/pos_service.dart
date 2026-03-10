import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../data/local/app_database.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/product.dart';
import '../domain/models/sale_history_fetch_result.dart';
import '../domain/models/sale_history_item.dart';
import '../domain/models/sync_queue_item.dart';

class PosService {
  PosService({
    required this.apiClient,
    required this.database,
  });

  final ApiClient apiClient;
  final AppDatabase database;
  final Uuid _uuid = const Uuid();

  Future<List<Product>> loadProducts() async {
    // Always try server first (online-first) so tablet stays in sync
    try {
      final remote = await refreshProducts();
      return remote;
    } catch (_) {
      // Fallback to local cache only when server is unreachable
      final local = await database.getProducts();
      return local;
    }
  }

  Future<List<Product>> refreshProducts() async {
    final data = await apiClient.getList('/products?active_only=1');
    final products = data.map((row) => Product.fromMap(row as Map<String, dynamic>)).toList();
    if (!kIsWeb) {
      await database.upsertProducts(products);
    }
    return products;
  }

  Future<String> submitSale({
    required List<CartItem> cart, 
    required String paymentMethod,
    String? customerName,
    String? customerPhone,
    DateTime? dueDate,
  }) async {
    if (cart.isEmpty) return '';

    final invoice = _buildInvoiceNumber();
    final payload = {
      'invoice_number': invoice,
      'outlet_id': AppConfig.defaultOutletId,
      'warehouse_id': AppConfig.defaultWarehouseId,
      'payment_method': paymentMethod,
      'order_type': 'DINE_IN',
      'items': cart.map((e) => e.toSaleItemMap()).toList(),
    };

    if (customerName != null) payload['customer_name'] = customerName;
    if (customerPhone != null) payload['customer_phone'] = customerPhone;
    if (dueDate != null) payload['due_date'] = dueDate.toIso8601String().substring(0, 10);

    final online = await _isOnline();
    if (online) {
      try {
        await apiClient.post('/sales', payload);
        return invoice;
      } catch (_) {
        // Fallback queue when API call fails.
      }
    }

    await database.enqueue(entityType: 'SALE', operation: 'CREATE', payload: payload);
    return invoice;
  }

  Future<int> pendingCount() async {
    return database.pendingCount();
  }

  Future<int> deadLetterCount() async {
    return database.deadLetterCount();
  }

  Future<List<SyncQueueItem>> deadLetterItems() async {
    return database.deadLetterQueue();
  }

  Future<List<SyncQueueItem>> recentSyncItems() async {
    return database.recentSyncQueue();
  }

  Future<void> requeueDeadLetterItem(int id) async {
    await database.requeueFailedItem(id);
  }

  Future<int> requeueAllDeadLetters() async {
    return database.requeueAllFailed();
  }

  Future<SaleHistoryFetchResult> fetchSaleHistory({
    int limit = 30,
    DateTime? from,
    DateTime? to,
  }) async {
    // On Web, fetch directly from API without local DB
    if (kIsWeb) {
      try {
        final data = await apiClient.getMap(
          _buildSaleHistoryPath(limit: limit, from: from, to: to),
        );
        final items = (data['items'] as List<dynamic>? ?? const []);
        final remoteItems = items.map((row) => SaleHistoryItem.fromMap(row as Map<String, dynamic>)).toList();
        return SaleHistoryFetchResult(items: remoteItems, fromCache: false);
      } catch (_) {
        return SaleHistoryFetchResult(items: [], fromCache: false);
      }
    }

    List<SaleHistoryItem> remoteItems;
    bool fromCache;

    try {
      final data = await apiClient.getMap(
        _buildSaleHistoryPath(limit: limit, from: from, to: to),
      );
      final items = (data['items'] as List<dynamic>? ?? const []);
      remoteItems = items.map((row) => SaleHistoryItem.fromMap(row as Map<String, dynamic>)).toList();
      await database.replaceSaleHistory(remoteItems);
      fromCache = false;
    } catch (_) {
      remoteItems = await database.getSaleHistory(limit: limit, from: from, to: to);
      fromCache = true;
    }

    final queuedItems = await database.getQueuedSaleHistory(limit: limit, from: from, to: to);
    final merged = _mergeHistory(remoteItems, queuedItems, limit: limit);
    return SaleHistoryFetchResult(items: merged, fromCache: fromCache);
  }

  Future<List<SaleHistoryItem>> fetchTempoSales() async {
    try {
      final list = await apiClient.getList('/sales/tempo?outlet_id=${AppConfig.defaultOutletId}');
      return list.map((row) => SaleHistoryItem.fromMap(row as Map<String, dynamic>)).toList();
    } catch (_) {
      return []; // Return empty on error for simplicity on Tempo UI
    }
  }

  String _buildInvoiceNumber() {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'INV-$date-${_uuid.v4().substring(0, 6).toUpperCase()}';
  }

  Future<bool> _isOnline() async {
    final status = await Connectivity().checkConnectivity();
    return !status.contains(ConnectivityResult.none);
  }

  String _buildSaleHistoryPath({
    required int limit,
    DateTime? from,
    DateTime? to,
  }) {
    final query = <String>[
      'outlet_id=${AppConfig.defaultOutletId}',
      'limit=$limit',
    ];

    if (from != null) {
      query.add('from=${from.toIso8601String().substring(0, 10)}');
    }
    if (to != null) {
      query.add('to=${to.toIso8601String().substring(0, 10)}');
    }

    return '/sales/history?${query.join('&')}';
  }

  List<SaleHistoryItem> _mergeHistory(
    List<SaleHistoryItem> remoteItems,
    List<SaleHistoryItem> queuedItems, {
    required int limit,
  }) {
    final map = <String, SaleHistoryItem>{};

    for (final item in remoteItems) {
      map[item.invoiceNumber] = item;
    }

    for (final item in queuedItems) {
      map[item.invoiceNumber] = item;
    }

    final merged = map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  Future<Map<String, dynamic>> getDashboardSummary(String date) async {
    return apiClient.getMap('/dashboard/summary?outlet_id=${AppConfig.defaultOutletId}&date=$date');
  }

  Future<Map<String, dynamic>> getDashboardTrend(int days) async {
    return apiClient.getMap('/dashboard/sales-trend?outlet_id=${AppConfig.defaultOutletId}&days=$days');
  }

  Future<Map<String, dynamic>> getDashboardTopProducts(String from, String to, int limit) async {
    return apiClient.getMap('/dashboard/top-products?outlet_id=${AppConfig.defaultOutletId}&from=$from&to=$to&limit=$limit');
  }

  Future<Map<String, dynamic>> getDashboardLowStock(int limit) async {
    return apiClient.getMap('/dashboard/low-stock?outlet_id=${AppConfig.defaultOutletId}&limit=$limit');
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final list = await apiClient.getList('/categories');
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> createProduct(Map<String, dynamic> data) async {
    if (data.containsKey('photo_file') && data['photo_file'] != null) {
      final filePath = data['photo_file'] as String;
      final fields = data.map((key, value) => MapEntry(key, value.toString()));
      fields.remove('photo_file');
      await apiClient.multipartRequest('/products', 'POST', fields, filePath, 'photo');
    } else {
      await apiClient.post('/products', data);
    }
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    if (data.containsKey('photo_file') && data['photo_file'] != null) {
      final filePath = data['photo_file'] as String;
      final fields = data.map((key, value) => MapEntry(key, value.toString()));
      fields.remove('photo_file');
      fields['_method'] = 'PUT'; // Laravel requires _method=PUT for multipart PUT requests
      await apiClient.multipartRequest('/products/$id', 'POST', fields, filePath, 'photo');
    } else {
      await apiClient.put('/products/$id', data);
    }
  }

  Future<void> deleteProduct(int id) async {
    await apiClient.delete('/products/$id');
  }

  // User Management
  Future<Map<String, dynamic>> getUsers() async {
    return apiClient.getMap('/users');
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    await apiClient.post('/users', data);
  }

  Future<void> toggleUserActive(int id) async {
    await apiClient.patch('/users/$id/toggle', {});
  }

  Future<void> resetUserPassword(int id, String newPassword) async {
    await apiClient.patch('/users/$id/reset-password', {'new_password': newPassword});
  }

  Future<void> deleteUser(int id) async {
    await apiClient.delete('/users/$id');
  }

  // Ingredients Management
  Future<Map<String, dynamic>> getIngredients() async {
    return apiClient.getMap('/ingredients');
  }

  Future<void> createIngredient(Map<String, dynamic> data) async {
    await apiClient.post('/ingredients', data);
  }

  Future<void> updateIngredientStock(int id, Map<String, dynamic> data) async {
    await apiClient.post('/ingredients/$id/stock', data);
  }

  Future<void> deleteIngredient(int id) async {
    await apiClient.delete('/ingredients/$id');
  }
}
