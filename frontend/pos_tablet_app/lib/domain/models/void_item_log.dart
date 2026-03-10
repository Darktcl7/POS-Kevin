class VoidItemLog {
  const VoidItemLog({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.reason,
    required this.performedBy,
    required this.createdAt,
    this.syncedAt,
  });

  final int id;
  final String productName;
  final int quantity;
  final String reason;
  final String performedBy;
  final DateTime createdAt;
  final DateTime? syncedAt;

  String get localLogId => id.toString();
}
