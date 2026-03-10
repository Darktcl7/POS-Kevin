class Product {
  const Product({
    required this.id,
    required this.productName,
    required this.sellingPrice,
    required this.costPrice,
    required this.taxPercent,
    required this.categoryName,
    this.imageUrl,
  });

  final int id;
  final String productName;
  final double sellingPrice;
  final double costPrice;
  final double taxPercent;
  final String categoryName;
  final String? imageUrl;

  /// Laba kotor per unit = harga jual - harga modal
  double get profitPerUnit => sellingPrice - costPrice;

  /// Margin persen = (laba / harga jual) * 100
  double get profitMarginPercent =>
      sellingPrice > 0 ? (profitPerUnit / sellingPrice) * 100 : 0;

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      productName: map['product_name'] as String,
      sellingPrice: (map['selling_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      taxPercent: (map['tax_percent'] as num?)?.toDouble() ?? 0,
      categoryName: (map['category_name'] ?? '-') as String,
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'product_name': productName,
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'tax_percent': taxPercent,
      'category_name': categoryName,
      'image_url': imageUrl,
      'is_active': 1,
    };
  }
}
