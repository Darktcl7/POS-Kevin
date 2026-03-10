class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.payload,
    required this.status,
    required this.retryCount,
    required this.nextRetryAt,
    required this.createdAt,
    this.syncedAt,
    this.lastError,
  });

  final int id;
  final String entityType;
  final String operation;
  final String payload;
  final String status;
  final int retryCount;
  final DateTime nextRetryAt;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String? lastError;
}
