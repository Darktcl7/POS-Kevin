import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.formatter,
    required this.onTap,
  });

  final Product product;
  final NumberFormat formatter;
  final VoidCallback onTap;

  /// Category-based icon mapping for beautiful fallback
  IconData _categoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('kopi') || cat.contains('coffee')) return Icons.coffee_rounded;
    if (cat.contains('teh') || cat.contains('tea')) return Icons.emoji_food_beverage_rounded;
    if (cat.contains('jus') || cat.contains('juice') || cat.contains('minum') || cat.contains('drink')) return Icons.local_drink_rounded;
    if (cat.contains('makan') || cat.contains('food') || cat.contains('snack')) return Icons.restaurant_rounded;
    if (cat.contains('kue') || cat.contains('cake') || cat.contains('pastry') || cat.contains('roti')) return Icons.cake_rounded;
    if (cat.contains('es') || cat.contains('ice')) return Icons.icecream_rounded;
    return Icons.local_cafe_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFd3dbdb)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF4F1E8),
                  gradient: hasImage
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E6F62).withOpacity(0.15),
                            const Color(0xFFF4F1E8),
                          ],
                        ),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF1E6F62).withOpacity(0.5),
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.productName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1f2d2e),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E6F62).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E6F62).withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatter.format(product.sellingPrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E6F62),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _categoryIcon(product.categoryName),
            size: 40,
            color: const Color(0xFF1E6F62).withOpacity(0.35),
          ),
          const SizedBox(height: 6),
          Text(
            product.categoryName,
            style: TextStyle(
              fontSize: 10,
              color: const Color(0xFF6B7A7B).withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
