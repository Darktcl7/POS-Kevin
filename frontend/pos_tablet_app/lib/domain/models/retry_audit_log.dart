class RetryAuditLog {
  const RetryAuditLog({
    required this.id,
    required this.actionType,
    required this.invoiceNumber,
    required this.status,
    required this.resultMessage,
    required this.performedBy,
    required this.createdAt,
    this.queueId,
    this.syncedAt,
  });

  final int id;
  final String actionType;
  final String invoiceNumber;
  final int? queueId;
  final String status;
  final String resultMessage;
  final String performedBy;
  final DateTime createdAt;
  final DateTime? syncedAt;

  String get localLogId => id.toString();
}
