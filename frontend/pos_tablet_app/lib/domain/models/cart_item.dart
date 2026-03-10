import 'product.dart';

class CartItem {
  CartItem({required this.product, this.quantity = 1});

  final Product product;
  int quantity;

  double get subtotal => product.sellingPrice * quantity;

  Map<String, Object?> toSaleItemMap() {
    return {
      'product_id': product.id,
      'product_name': product.productName,
      'quantity': quantity,
      'price': product.sellingPrice,
    };
  }
}
