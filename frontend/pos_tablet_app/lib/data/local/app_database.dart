import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/product.dart';
import '../../domain/models/retry_audit_log.dart';
import '../../domain/models/sale_history_item.dart';
import '../../domain/models/sync_queue_item.dart';
import '../../domain/models/void_item_log.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._();

  AppDatabase._();

  Database? _db;
  
  // In-memory settings for Web (no sqflite needed)
  final Map<String, String> _webSettings = {};
  
  bool get _isWebMode => kIsWeb;

  Future<Database> get db async {
    if (_isWebMode) {
      throw UnsupportedError('Database not available on Web. Use getSetting/setSetting instead.');
    }
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'pos_kevin.db');

    return openDatabase(
      path,
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY,
            product_name TEXT NOT NULL,
            selling_price REAL NOT NULL,
            cost_price REAL NOT NULL DEFAULT 0,
            tax_percent REAL NOT NULL DEFAULT 0,
            category_name TEXT,
            image_url TEXT,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced_at TEXT,
            last_error TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sale_history (
            sale_id INTEGER PRIMARY KEY,
            invoice_number TEXT NOT NULL,
            total_amount REAL NOT NULL,
            created_at TEXT NOT NULL,
            payload TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE retry_audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            invoice_number TEXT NOT NULL,
            queue_id INTEGER,
            status TEXT NOT NULL,
            result_message TEXT NOT NULL,
            performed_by TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE void_item_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            reason TEXT NOT NULL,
            performed_by TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced_at TEXT
          )
        ''');

        // ==== CREATE PERFORMANCE INDEXES ====
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status, next_retry_at)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_history_date ON sale_history (created_at)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_active ON products (is_active)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE sync_queue ADD COLUMN next_retry_at TEXT');
          await db.execute('ALTER TABLE sync_queue ADD COLUMN synced_at TEXT');

          final now = DateTime.now().toIso8601String();
          await db.update(
            'sync_queue',
            {'next_retry_at': now},
            where: 'next_retry_at IS NULL',
          );
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sale_history (
              sale_id INTEGER PRIMARY KEY,
              invoice_number TEXT NOT NULL,
              total_amount REAL NOT NULL,
              created_at TEXT NOT NULL,
              payload TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS retry_audit_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action_type TEXT NOT NULL,
              invoice_number TEXT NOT NULL,
              queue_id INTEGER,
              status TEXT NOT NULL,
              result_message TEXT NOT NULL,
              performed_by TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 5) {
          await db.execute('ALTER TABLE retry_audit_logs ADD COLUMN synced_at TEXT');
        }

        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS void_item_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_name TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              reason TEXT NOT NULL,
              performed_by TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 7) {
          await db.execute('ALTER TABLE void_item_logs ADD COLUMN synced_at TEXT');
        }

        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN image_url TEXT');
          } catch (_) {}
        }

        if (oldVersion < 9) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN cost_price REAL NOT NULL DEFAULT 0');
          } catch (_) {}
        }

        if (oldVersion < 10) {
          try {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status, next_retry_at)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_history_date ON sale_history (created_at)');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_products_active ON products (is_active)');
          } catch (_) {}
        }
      },
    );
  }

  Future<void> upsertProducts(List<Product> products) async {
    final database = await db;
    final batch = database.batch();

    for (final product in products) {
      batch.insert(
        'products',
        product.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Product>> getProducts() async {
    final database = await db;
    final rows = await database.query('products', where: 'is_active = 1', orderBy: 'product_name ASC');
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  Future<int> enqueue({
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final database = await db;
    final now = DateTime.now().toIso8601String();

    return database.insert('sync_queue', {
      'entity_type': entityType,
      'operation': operation,
      'payload': jsonEncode(payload),
      'status': 'PENDING',
      'retry_count': 0,
      'next_retry_at': now,
      'created_at': now,
    });
  }

  Future<List<SyncQueueItem>> dueQueue() async {
    final database = await db;
    final now = DateTime.now().toIso8601String();

    final rows = await database.query(
      'sync_queue',
      where: 'status = ? AND next_retry_at <= ?',
      whereArgs: ['PENDING', now],
      orderBy: 'id ASC',
      limit: 50,
    );

    return rows.map(_toSyncQueueItem).toList();
  }

  Future<int> pendingCount() async {
    final database = await db;
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sync_queue WHERE status = ?',
      ['PENDING'],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<int> deadLetterCount() async {
    final database = await db;
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sync_queue WHERE status = ?',
      ['FAILED_PERMANENT'],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<List<SyncQueueItem>> deadLetterQueue({int limit = 100}) async {
    final database = await db;
    final rows = await database.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['FAILED_PERMANENT'],
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(_toSyncQueueItem).toList();
  }

  Future<List<SyncQueueItem>> recentSyncQueue({int limit = 100}) async {
    final database = await db;
    final rows = await database.query(
      'sync_queue',
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(_toSyncQueueItem).toList();
  }

  Future<void> markSynced(int id) async {
    final database = await db;
    await database.update(
      'sync_queue',
      {
        'status': 'SYNCED',
        'synced_at': DateTime.now().toIso8601String(),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> scheduleRetry({
    required int id,
    required int retryCount,
    required DateTime nextRetryAt,
    required String lastError,
  }) async {
    final database = await db;

    await database.update(
      'sync_queue',
      {
        'retry_count': retryCount,
        'next_retry_at': nextRetryAt.toIso8601String(),
        'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markPermanentFailure({required int id, required String lastError}) async {
    final database = await db;

    await database.update(
      'sync_queue',
      {
        'status': 'FAILED_PERMANENT',
        'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> requeueFailedItem(int id) async {
    final database = await db;
    final now = DateTime.now().toIso8601String();
    await database.update(
      'sync_queue',
      {
        'status': 'PENDING',
        'retry_count': 0,
        'next_retry_at': now,
        'last_error': null,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, 'FAILED_PERMANENT'],
    );
  }

  Future<int> requeueAllFailed() async {
    final database = await db;
    final now = DateTime.now().toIso8601String();
    return database.update(
      'sync_queue',
      {
        'status': 'PENDING',
        'retry_count': 0,
        'next_retry_at': now,
        'last_error': null,
      },
      where: 'status = ?',
      whereArgs: ['FAILED_PERMANENT'],
    );
  }

  Future<void> setSetting(String key, String value) async {
    if (_isWebMode) {
      _webSettings[key] = value;
      return;
    }
    final database = await db;
    await database.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    if (_isWebMode) {
      return _webSettings[key];
    }
    final database = await db;
    final rows = await database.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> replaceSaleHistory(List<SaleHistoryItem> sales) async {
    final database = await db;
    final batch = database.batch();

    await database.delete('sale_history');

    for (final sale in sales) {
      batch.insert(
        'sale_history',
        {
          'sale_id': sale.id,
          'invoice_number': sale.invoiceNumber,
          'total_amount': sale.totalAmount,
          'created_at': sale.createdAt.toIso8601String(),
          'payload': jsonEncode(sale.toMap()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<SaleHistoryItem>> getSaleHistory({
    int limit = 40,
    DateTime? from,
    DateTime? to,
  }) async {
    final database = await db;
    final where = <String>[];
    final whereArgs = <Object?>[];

    if (from != null) {
      where.add('created_at >= ?');
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at <= ?');
      whereArgs.add(to.toIso8601String());
    }

    final rows = await database.query(
      'sale_history',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map((row) {
      final payload = row['payload'] as String? ?? '{}';
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return SaleHistoryItem.fromMap(decoded);
    }).toList();
  }

  Future<List<SaleHistoryItem>> getQueuedSaleHistory({
    int limit = 40,
    DateTime? from,
    DateTime? to,
  }) async {
    final database = await db;
    final where = <String>[
      'entity_type = ?',
      'operation = ?',
      'status IN (?, ?)',
    ];
    final whereArgs = <Object?>['SALE', 'CREATE', 'PENDING', 'FAILED_PERMANENT'];

    if (from != null) {
      where.add('created_at >= ?');
      whereArgs.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at <= ?');
      whereArgs.add(to.toIso8601String());
    }

    final rows = await database.query(
      'sync_queue',
      where: where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map((row) {
      final payloadRaw = row['payload'] as String? ?? '{}';
      final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      final items = (payload['items'] as List<dynamic>? ?? const []);
      final details = items.map((item) {
        final map = item as Map<String, dynamic>;
        final qty = (map['quantity'] as num?)?.toDouble() ?? 0;
        final price = (map['price'] as num?)?.toDouble() ?? 0;
        final subtotal = qty * price;
        final productName = (map['product_name'] ?? 'Product #${map['product_id'] ?? '-'}').toString();
        return SaleHistoryLine(
          productName: productName,
          quantity: qty,
          price: price,
          subtotal: subtotal,
        );
      }).toList();

      final total = details.fold<double>(0, (sum, line) => sum + line.subtotal);
      final createdAt = DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now();
      final queueId = row['id'] as int;

      return SaleHistoryItem(
        id: -queueId,
        invoiceNumber: (payload['invoice_number'] ?? 'QUEUE-$queueId').toString(),
        totalAmount: total,
        syncStatus: (row['status'] as String?) ?? 'PENDING',
        paymentMethod: (payload['payment_method'] ?? 'CASH').toString(),
        orderType: (payload['order_type'] ?? 'DINE_IN').toString(),
        createdAt: createdAt,
        details: details,
        localOnly: true,
      );
    }).toList();
  }

  Future<void> insertRetryAuditLog({
    required String actionType,
    required String invoiceNumber,
    required int? queueId,
    required String status,
    required String resultMessage,
    required String performedBy,
  }) async {
    final database = await db;
    await database.insert('retry_audit_logs', {
      'action_type': actionType,
      'invoice_number': invoiceNumber,
      'queue_id': queueId,
      'status': status,
      'result_message': resultMessage,
      'performed_by': performedBy,
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': null,
    });
  }

  Future<List<RetryAuditLog>> recentRetryAuditLogs({int limit = 50}) async {
    final database = await db;
    final rows = await database.query(
      'retry_audit_logs',
      orderBy: 'id DESC',
      limit: limit,
    );

    return rows.map((row) {
      return RetryAuditLog(
        id: row['id'] as int,
        actionType: (row['action_type'] ?? '').toString(),
        invoiceNumber: (row['invoice_number'] ?? '-').toString(),
        queueId: row['queue_id'] as int?,
        status: (row['status'] ?? '').toString(),
        resultMessage: (row['result_message'] ?? '').toString(),
        performedBy: (row['performed_by'] ?? '-').toString(),
        createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
        syncedAt: DateTime.tryParse((row['synced_at'] ?? '').toString()),
      );
    }).toList();
  }

  Future<int> retryAuditLogCount() async {
    final database = await db;
    final rows = await database.rawQuery('SELECT COUNT(*) AS cnt FROM retry_audit_logs');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<int> unsyncedRetryAuditLogCount() async {
    final database = await db;
    final rows = await database.rawQuery('SELECT COUNT(*) AS cnt FROM retry_audit_logs WHERE synced_at IS NULL');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<int> pruneRetryAuditLogs({required int keepDays}) async {
    final database = await db;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
    return database.delete(
      'retry_audit_logs',
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<List<RetryAuditLog>> unsyncedRetryAuditLogs({int limit = 200}) async {
    final database = await db;
    final rows = await database.query(
      'retry_audit_logs',
      where: 'synced_at IS NULL',
      orderBy: 'id ASC',
      limit: limit,
    );

    return rows.map((row) {
      return RetryAuditLog(
        id: row['id'] as int,
        actionType: (row['action_type'] ?? '').toString(),
        invoiceNumber: (row['invoice_number'] ?? '-').toString(),
        queueId: row['queue_id'] as int?,
        status: (row['status'] ?? '').toString(),
        resultMessage: (row['result_message'] ?? '').toString(),
        performedBy: (row['performed_by'] ?? '-').toString(),
        createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
        syncedAt: DateTime.tryParse((row['synced_at'] ?? '').toString()),
      );
    }).toList();
  }

  Future<void> markRetryAuditLogsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final database = await db;
    final now = DateTime.now().toIso8601String();
    final placeholders = List.filled(ids.length, '?').join(',');
    await database.rawUpdate(
      'UPDATE retry_audit_logs SET synced_at = ? WHERE id IN ($placeholders)',
      [now, ...ids],
    );
  }

  Future<void> insertVoidItemLog({
    required String productName,
    required int quantity,
    required String reason,
    required String performedBy,
  }) async {
    final database = await db;
    await database.insert('void_item_logs', {
      'product_name': productName,
      'quantity': quantity,
      'reason': reason,
      'performed_by': performedBy,
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': null,
    });
  }

  Future<List<VoidItemLog>> recentVoidItemLogs({int limit = 50}) async {
    final database = await db;
    final rows = await database.query(
      'void_item_logs',
      orderBy: 'id DESC',
      limit: limit,
    );

    return rows.map((row) {
      return VoidItemLog(
        id: row['id'] as int,
        productName: (row['product_name'] ?? '-').toString(),
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        reason: (row['reason'] ?? '-').toString(),
        performedBy: (row['performed_by'] ?? '-').toString(),
        createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
        syncedAt: DateTime.tryParse((row['synced_at'] ?? '').toString()),
      );
    }).toList();
  }

  Future<int> unsyncedVoidItemLogCount() async {
    final database = await db;
    final rows = await database.rawQuery('SELECT COUNT(*) AS cnt FROM void_item_logs WHERE synced_at IS NULL');
    return (rows.first['cnt'] as int?) ?? 0;
  }

  Future<List<VoidItemLog>> unsyncedVoidItemLogs({int limit = 200}) async {
    final database = await db;
    final rows = await database.query(
      'void_item_logs',
      where: 'synced_at IS NULL',
      orderBy: 'id ASC',
      limit: limit,
    );

    return rows.map((row) {
      return VoidItemLog(
        id: row['id'] as int,
        productName: (row['product_name'] ?? '-').toString(),
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        reason: (row['reason'] ?? '-').toString(),
        performedBy: (row['performed_by'] ?? '-').toString(),
        createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ?? DateTime.now(),
        syncedAt: DateTime.tryParse((row['synced_at'] ?? '').toString()),
      );
    }).toList();
  }

  Future<void> markVoidItemLogsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final database = await db;
    final now = DateTime.now().toIso8601String();
    final placeholders = List.filled(ids.length, '?').join(',');
    await database.rawUpdate(
      'UPDATE void_item_logs SET synced_at = ? WHERE id IN ($placeholders)',
      [now, ...ids],
    );
  }

  SyncQueueItem _toSyncQueueItem(Map<String, Object?> row) {
    DateTime parseDate(String? input, DateTime fallback) {
      final parsed = DateTime.tryParse(input ?? '');
      return parsed ?? fallback;
    }

    return SyncQueueItem(
      id: row['id'] as int,
      entityType: row['entity_type'] as String,
      operation: row['operation'] as String,
      payload: row['payload'] as String,
      status: row['status'] as String,
      retryCount: (row['retry_count'] as int?) ?? 0,
      nextRetryAt: parseDate(row['next_retry_at'] as String?, DateTime.now()),
      createdAt: parseDate(row['created_at'] as String?, DateTime.now()),
      syncedAt: DateTime.tryParse((row['synced_at'] as String?) ?? ''),
      lastError: row['last_error'] as String?,
    );
  }
}
