class HeldOrderItem {
  const HeldOrderItem({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final int quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'quantity': quantity,
    };
  }

  factory HeldOrderItem.fromMap(Map<String, dynamic> map) {
    return HeldOrderItem(
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class HeldOrder {
  const HeldOrder({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final List<HeldOrderItem> items;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory HeldOrder.fromMap(Map<String, dynamic> map) {
    return HeldOrder(
      id: (map['id'] ?? '').toString(),
      label: (map['label'] ?? 'Hold Order').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
      items: ((map['items'] as List<dynamic>? ?? const []))
          .map((e) => HeldOrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
