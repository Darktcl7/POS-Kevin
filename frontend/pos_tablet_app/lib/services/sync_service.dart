import 'dart:convert';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../data/local/app_database.dart';
import '../domain/models/sync_queue_item.dart';

class SyncService {
  SyncService({required this.apiClient, required this.database});

  final ApiClient apiClient;
  final AppDatabase database;

  static const int _maxRetry = 7;

  Future<int> syncPending() async {
    final queue = await database.dueQueue();
    var synced = 0;

    for (final item in queue) {
      try {
        await _sendItem(item);
        await database.markSynced(item.id);
        synced++;
      } catch (e) {
        await _handleRetry(item, e.toString());
      }
    }

    return synced;
  }

  Future<void> _sendItem(SyncQueueItem item) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;

    if (item.entityType == 'SALE' && item.operation == 'CREATE') {
      await apiClient.post('/sales', payload);
      return;
    }

    throw Exception('Unsupported sync entity: ${item.entityType}/${item.operation}');
  }

  Future<void> _handleRetry(SyncQueueItem item, String errorMessage) async {
    final nextRetryCount = item.retryCount + 1;

    if (nextRetryCount >= _maxRetry) {
      await database.markPermanentFailure(id: item.id, lastError: errorMessage);
      return;
    }

    final delaySeconds = _calculateBackoffSeconds(nextRetryCount);
    final nextRetryAt = DateTime.now().add(Duration(seconds: delaySeconds));

    await database.scheduleRetry(
      id: item.id,
      retryCount: nextRetryCount,
      nextRetryAt: nextRetryAt,
      lastError: errorMessage,
    );
  }

  int _calculateBackoffSeconds(int retryCount) {
    final seconds = 15 * (1 << (retryCount - 1));
    return seconds > 900 ? 900 : seconds;
  }

  Future<int> syncRetryAuditLogs({required String deviceId}) async {
    final logs = await database.unsyncedRetryAuditLogs(limit: 200);
    if (logs.isEmpty) return 0;

    final payload = {
      'device_id': deviceId,
      'outlet_id': AppConfig.defaultOutletId,
      'logs': logs
          .map((log) => {
                'local_log_id': log.localLogId,
                'action_type': log.actionType,
                'invoice_number': log.invoiceNumber,
                'queue_id': log.queueId?.toString(),
                'status': log.status,
                'result_message': log.resultMessage,
                'performed_by': log.performedBy,
                'logged_at': log.createdAt.toIso8601String(),
              })
          .toList(),
    };

    final result = await apiClient.post('/sync/retry-audit-logs', payload);
    final acceptedIdsRaw = (result['accepted_local_ids'] as List<dynamic>? ?? const []);
    final acceptedLocalIds = acceptedIdsRaw.map((e) => e.toString()).toSet();

    final toMark = logs.where((log) => acceptedLocalIds.contains(log.localLogId)).map((log) => log.id).toList();
    await database.markRetryAuditLogsSynced(toMark);
    return toMark.length;
  }

  Future<int> syncVoidItemLogs({required String deviceId}) async {
    final logs = await database.unsyncedVoidItemLogs(limit: 200);
    if (logs.isEmpty) return 0;

    final payload = {
      'device_id': deviceId,
      'outlet_id': AppConfig.defaultOutletId,
      'logs': logs
          .map((log) => {
                'local_log_id': log.localLogId,
                'product_name': log.productName,
                'quantity': log.quantity,
                'reason': log.reason,
                'performed_by': log.performedBy,
                'logged_at': log.createdAt.toIso8601String(),
              })
          .toList(),
    };

    final result = await apiClient.post('/sync/void-item-logs', payload);
    final acceptedIdsRaw = (result['accepted_local_ids'] as List<dynamic>? ?? const []);
    final acceptedLocalIds = acceptedIdsRaw.map((e) => e.toString()).toSet();

    final toMark = logs.where((log) => acceptedLocalIds.contains(log.localLogId)).map((log) => log.id).toList();
    await database.markVoidItemLogsSynced(toMark);
    return toMark.length;
  }
}
