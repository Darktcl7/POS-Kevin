class SaleHistoryLine {
  const SaleHistoryLine({
    required this.productName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  final String productName;
  final double quantity;
  final double price;
  final double subtotal;

  factory SaleHistoryLine.fromMap(Map<String, dynamic> map) {
    return SaleHistoryLine(
      productName: (map['product_name'] ?? '-') as String,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
    };
  }
}

class SaleHistoryItem {
  const SaleHistoryItem({
    required this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.syncStatus,
    required this.paymentMethod,
    required this.orderType,
    required this.createdAt,
    required this.details,
    this.customerName,
    this.customerPhone,
    this.dueDate,
    this.paymentStatus,
    this.localOnly = false,
  });

  final int id;
  final String invoiceNumber;
  final double totalAmount;
  final String syncStatus;
  final String paymentMethod;
  final String orderType;
  final DateTime createdAt;
  final List<SaleHistoryLine> details;
  final String? customerName;
  final String? customerPhone;
  final DateTime? dueDate;
  final String? paymentStatus;
  final bool localOnly;

  factory SaleHistoryItem.fromMap(Map<String, dynamic> map) {
    return SaleHistoryItem(
      id: map['id'] as int,
      invoiceNumber: (map['invoice_number'] ?? '-') as String,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      syncStatus: (map['sync_status'] ?? 'SYNCED') as String,
      paymentMethod: (map['payment_method'] ?? '-') as String,
      orderType: (map['order_type'] ?? '-') as String,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) : null,
      paymentStatus: map['payment_status'] as String?,
      details: ((map['details'] as List<dynamic>? ?? const []))
          .map((e) => SaleHistoryLine.fromMap(e as Map<String, dynamic>))
          .toList(),
      localOnly: (map['local_only'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'sync_status': syncStatus,
      'payment_method': paymentMethod,
      'order_type': orderType,
      'created_at': createdAt.toIso8601String(),
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'due_date': dueDate?.toIso8601String(),
      'payment_status': paymentStatus,
      'details': details.map((e) => e.toMap()).toList(),
      'local_only': localOnly,
    };
  }
}
