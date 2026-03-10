import 'sale_history_item.dart';

class SaleHistoryFetchResult {
  const SaleHistoryFetchResult({
    required this.items,
    required this.fromCache,
  });

  final List<SaleHistoryItem> items;
  final bool fromCache;
}
