import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/pos_store.dart';
import '../core/config/app_config.dart';
import '../widgets/checkout_dialog.dart';
import '../widgets/product_card.dart';

class CashierView extends StatefulWidget {
  const CashierView({required this.store});
  final PosStore store;
  @override
  State<CashierView> createState() => CashierViewState();
}

class CashierViewState extends State<CashierView> {
  String _selectedCategory = 'Semua';
  bool _showSuccessPanel = false;
  String _lastPaymentMethod = '';

  Future<bool> _voidCartItem(BuildContext context, PosStore store, int productId) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.light().copyWith(
          dialogBackgroundColor: const Color(0xFFFFFFFF),
          colorScheme: const ColorScheme.light(primary: Color(0xFF1E6F62), surface: Color(0xFFFFFFFF)),
        ),
        child: AlertDialog(
          backgroundColor: const Color(0xFFFFFFFF),
          title: const Text('Void Item', style: TextStyle(color: Color(0xFF1f2d2e))),
          content: TextField(
            controller: reasonCtrl,
            style: const TextStyle(color: Color(0xFF1f2d2e)),
            decoration: const InputDecoration(labelText: 'Alasan void'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, reasonCtrl.text), child: const Text('Void')),
          ],
        ),
      ),
    );
    if (reason == null) return false;
    await store.removeFromCartWithReason(productId, reason);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive: adjust cart panel width based on screen
    final cartPanelWidth = screenWidth > 1200 ? 400.0 : (screenWidth > 900 ? 360.0 : 320.0);

    final categories = ['Semua'];
    for (var p in store.products) {
      if (!categories.contains(p.categoryName)) categories.add(p.categoryName);
    }

    final filteredProducts = store.filteredProducts.where((p) {
       if (_selectedCategory == 'Semua') return true;
       return p.categoryName == _selectedCategory;
    }).toList();

    return Row(
      children: [
        // ── Left: Product Grid ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, Kevin', style: TextStyle(fontSize: screenWidth > 1100 ? 32 : 24, fontWeight: FontWeight.w600, color: const Color(0xFF1f2d2e))),
                          const SizedBox(height: 4),
                          const Text('Discover whatever you need easily', style: TextStyle(fontSize: 14, color: Color(0xFF6b7a7b))),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFd3dbdb)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: store.status.contains('Error') || store.status.contains('gagal') || store.status.contains('Gagal')
                                    ? Colors.red
                                    : const Color(0xFF027a48),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: screenWidth > 1100 ? 200 : 120),
                                child: Text(
                                  store.status,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1f2d2e)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => store.syncNow(),
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.sync,
                              key: ValueKey(store.syncing),
                              color: store.syncing ? const Color(0xFFb54708) : const Color(0xFF6b7a7b),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Search Bar
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFd3dbdb)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF6b7a7b), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: store.setProductSearchQuery,
                          style: const TextStyle(color: Color(0xFF1f2d2e), fontSize: 14),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Search products...',
                            hintStyle: TextStyle(color: Color(0xFF6b7a7b), fontSize: 14),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                        ),
                      ),
                      if (store.productSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => store.setProductSearchQuery(''),
                          child: const Icon(Icons.close, color: Color(0xFF6b7a7b), size: 18),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isActive = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF1E6F62) : const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isActive ? Colors.transparent : const Color(0xFFd3dbdb),
                            ),
                          ),
                          child: Text(
                            cat, 
                            style: TextStyle(
                              color: isActive ? const Color(0xFFFFFFFF) : const Color(0xFF6b7a7b),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Product Grid
                Expanded(
                  child: store.loading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E6F62)))
                    : filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: const Color(0xFF6b7a7b).withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              const Text('Tidak ada produk ditemukan', style: TextStyle(color: Color(0xFF6b7a7b), fontSize: 16)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                             maxCrossAxisExtent: screenWidth > 1200 ? 220 : 200,
                             childAspectRatio: 0.75,
                             crossAxisSpacing: 16,
                             mainAxisSpacing: 16,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ProductCard(
                              product: product,
                              formatter: formatter,
                              onTap: () => store.addToCart(product),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        
        // ── Right: Cart Panel (or Success Panel) ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: _showSuccessPanel 
          ? Container(
              key: const ValueKey('SuccessPanel'),
              width: cartPanelWidth,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1CD485), Color(0xFF18B070)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment Successful!',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order paid via $_lastPaymentMethod',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
                    ),
                  ],
                ),
              ),
            )
          : Container(
            key: const ValueKey('CartPanel'),
            width: cartPanelWidth,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              border: Border(left: BorderSide(color: Color(0xFFD3DBDB))),
            ),
            child: Column(
              children: [
                 // Cart Header
                 Padding(
                   padding: const EdgeInsets.all(20),
                   child: Column(
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text('Current Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1f2d2e))),
                           Row(
                             children: [
                               if (store.cart.isNotEmpty)
                                 GestureDetector(
                                   onTap: () => store.clearCart(),
                                   child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                     decoration: BoxDecoration(
                                       color: Colors.red.withOpacity(0.1),
                                       borderRadius: BorderRadius.circular(8),
                                     ),
                                     child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                                   ),
                                 ),
                               const SizedBox(width: 8),
                               GestureDetector(
                                 onTap: store.cart.isEmpty ? null : () => store.holdCurrentOrder(),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFF6b7a7b).withOpacity(0.08),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: const Text('Hold', style: TextStyle(fontSize: 12, color: Color(0xFF6b7a7b), fontWeight: FontWeight.w600)),
                                 ),
                               ),
                             ],
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),

                       // Held orders (compact)
                       if (store.heldOrders.isNotEmpty)
                         SizedBox(
                           height: 36,
                           child: ListView.separated(
                             scrollDirection: Axis.horizontal,
                             separatorBuilder: (_, __) => const SizedBox(width: 8),
                             itemCount: store.heldOrders.length,
                             itemBuilder: (_, i) {
                               final h = store.heldOrders[i];
                               return GestureDetector(
                                 onTap: () {
                                   if (store.cart.isEmpty) store.resumeHeldOrder(h.id);
                                 },
                                 onLongPress: () => store.deleteHeldOrder(h.id),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFF1E6F62).withOpacity(0.12),
                                     borderRadius: BorderRadius.circular(8),
                                     border: Border.all(color: const Color(0xFF1E6F62).withOpacity(0.25)),
                                   ),
                                   child: Text(h.label, style: const TextStyle(fontSize: 12, color: Color(0xFF1E6F62), fontWeight: FontWeight.w600)),
                                 ),
                               );
                             },
                           ),
                         ),
                       if (store.heldOrders.isNotEmpty) const SizedBox(height: 12),

                       // Payment method toggle
                       Container(
                         padding: const EdgeInsets.all(4),
                         decoration: BoxDecoration(color: const Color(0xFFf4f8f7), borderRadius: BorderRadius.circular(14)),
                         child: Row(
                           children: [
                             _buildPaymentTab('Cash', 'CASH', store),
                             _buildPaymentTab('QRIS', 'QRIS', store),
                             _buildPaymentTab('Tempo', 'TEMPO', store),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
                 Divider(color: const Color(0xFFd3dbdb), height: 1),
                 
                 // Cart Items
                 Expanded(
                   child: store.cart.isEmpty 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 48, color: const Color(0xFF6B7A7B).withOpacity(0.3)),
                            const SizedBox(height: 12),
                            const Text('Keranjang masih kosong', style: TextStyle(color: Color(0xFF6B7A7B), fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('Tap produk untuk menambah', style: TextStyle(color: Color(0xFF6B7A7B), fontSize: 11)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: store.cart.length,
                        itemBuilder: (context, index) {
                           final item = store.cart[index];
                           final hasImg = item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty;
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 16),
                             child: Row(
                               children: [
                                 // Thumbnail
                                 Container(
                                   width: 52, height: 52,
                                   decoration: BoxDecoration(
                                     borderRadius: BorderRadius.circular(12),
                                     color: const Color(0xFFF4F1E8),
                                   ),
                                   child: hasImg
                                       ? ClipRRect(
                                           borderRadius: BorderRadius.circular(12),
                                           child: Image.network(item.product.imageUrl!, fit: BoxFit.cover,
                                             errorBuilder: (_, __, ___) => _cartItemPlaceholder(item.product.categoryName),
                                           ),
                                         )
                                       : _cartItemPlaceholder(item.product.categoryName),
                                 ),
                                 const SizedBox(width: 12),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(item.product.productName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF1f2d2e)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                       const SizedBox(height: 3),
                                       Text(formatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E6F62), fontSize: 13)),
                                     ],
                                   ),
                                 ),
                                 // Qty controls
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                   decoration: BoxDecoration(color: const Color(0xFFf4f8f7), borderRadius: BorderRadius.circular(12)),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       GestureDetector(
                                          onTap: () {
                                            if (item.quantity == 1) {
                                              _voidCartItem(context, store, item.product.id);
                                            } else {
                                              store.decreaseCartQty(item.product.id);
                                            }
                                          },
                                          child: Container(width: 30, height: 30, alignment: Alignment.center, child: Icon(item.quantity == 1 ? Icons.delete_outline : Icons.remove, size: 16, color: item.quantity == 1 ? Colors.red.shade400 : const Color(0xFF1f2d2e))),
                                       ),
                                       SizedBox(width: 28, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1f2d2e)))),
                                       GestureDetector(
                                          onTap: () => store.increaseCartQty(item.product.id),
                                          child: Container(width: 30, height: 30, alignment: Alignment.center, child: const Icon(Icons.add, size: 16, color: Color(0xFF1f2d2e))),
                                       ),
                                     ],
                                   ),
                                 ),
                               ],
                             ),
                           );
                        },
                    ),
                 ),

                 // Cart Footer / Checkout
                 Container(
                   padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                   decoration: BoxDecoration(
                     color: const Color(0xFFFFFFFF),
                     border: Border(top: BorderSide(color: const Color(0xFFd3dbdb))),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Cash Input (only when CASH)
                       if (store.isCashPayment && store.cart.isNotEmpty) ...[
                         const Text('Nominal Tunai', style: TextStyle(color: Color(0xFF6b7a7b), fontSize: 12, fontWeight: FontWeight.w600)),
                         const SizedBox(height: 6),
                         Container(
                           height: 46,
                           padding: const EdgeInsets.symmetric(horizontal: 14),
                           decoration: BoxDecoration(
                             color: const Color(0xFFFFFFFF),
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: const Color(0xFFd3dbdb)),
                           ),
                           child: Row(
                             children: [
                               const Text('Rp', style: TextStyle(color: Color(0xFF1E6F62), fontWeight: FontWeight.w700, fontSize: 15)),
                               const SizedBox(width: 8),
                               Expanded(
                                 child: TextField(
                                   keyboardType: TextInputType.number,
                                   onChanged: store.setCashReceivedInput,
                                   style: const TextStyle(color: Color(0xFF1f2d2e), fontSize: 16, fontWeight: FontWeight.w600),
                                   decoration: const InputDecoration(
                                     border: InputBorder.none,
                                     enabledBorder: InputBorder.none,
                                     focusedBorder: InputBorder.none,
                                     hintText: '0',
                                     hintStyle: TextStyle(color: Color(0xFF6b7a7b)),
                                     isDense: true,
                                     contentPadding: EdgeInsets.zero,
                                     filled: false,
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(height: 8),
                         // Quick Cash Buttons
                         if (store.quickCashSuggestions.isNotEmpty)
                           Wrap(
                             spacing: 6,
                             runSpacing: 6,
                             children: store.quickCashSuggestions.map((amount) {
                               final isExact = amount == store.cartTotal;
                               return GestureDetector(
                                 onTap: () => store.setCashReceivedAmount(amount),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                   decoration: BoxDecoration(
                                     color: isExact
                                         ? const Color(0xFF1E6F62).withOpacity(0.15)
                                         : const Color(0xFFf4f8f7),
                                     borderRadius: BorderRadius.circular(10),
                                     border: Border.all(
                                       color: isExact
                                           ? const Color(0xFF1E6F62).withOpacity(0.4)
                                           : const Color(0xFFd3dbdb),
                                     ),
                                   ),
                                   child: Text(
                                     formatter.format(amount),
                                     style: TextStyle(
                                       fontSize: 12,
                                       fontWeight: FontWeight.w600,
                                       color: isExact ? const Color(0xFF1E6F62) : const Color(0xFF1f2d2e),
                                     ),
                                   ),
                                 ),
                               );
                             }).toList(),
                           ),
                         const SizedBox(height: 12),
                       ],

                       _summaryRow('Subtotal', formatter.format(store.cartTotal), false),
                       const SizedBox(height: 6),
                       _summaryRow('Tax', 'Rp 0', false),
                       if (store.isCashPayment && store.cashReceivedAmount > 0) ...[
                         const SizedBox(height: 6),
                         _summaryRow('Tunai', formatter.format(store.cashReceivedAmount), false),
                         const SizedBox(height: 6),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text('Kembalian', style: TextStyle(color: Color(0xFF6B7A7B), fontSize: 14, fontWeight: FontWeight.w500)),
                             Text(
                               formatter.format(store.cashChangeAmount),
                               style: TextStyle(
                                 fontSize: 14,
                                 fontWeight: FontWeight.w700,
                                 color: store.cashChangeAmount >= 0 ? const Color(0xFF027a48) : Colors.red.shade400,
                               ),
                             ),
                           ],
                         ),
                       ],
                       const SizedBox(height: 10),
                       Container(
                         padding: const EdgeInsets.only(top: 10),
                         decoration: BoxDecoration(
                           border: Border(top: BorderSide(color: const Color(0xFFd3dbdb))),
                         ),
                         child: _summaryRow('Total', formatter.format(store.cartTotal), true),
                       ),
                       const SizedBox(height: 16),
                       // Pay Now button
                       SizedBox(
                         width: double.infinity,
                         height: 56,
                         child: ElevatedButton(
                           style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF1E6F62),
                             foregroundColor: const Color(0xFFFFFFFF),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             elevation: 8,
                             shadowColor: const Color(0xFF1E6F62).withOpacity(0.3),
                             disabledBackgroundColor: const Color(0xFF1E6F62).withOpacity(0.4),
                           ),
                           onPressed: (!store.canCheckout || store.checkouting) ? null : () async {
                              final result = await showDialog<dynamic>(
                                context: context,
                                builder: (ctx) => Theme(
                                   data: ThemeData.light().copyWith(
                                     dialogBackgroundColor: const Color(0xFFFFFFFF),
                                     colorScheme: const ColorScheme.light(primary: Color(0xFF1E6F62), surface: Color(0xFFFFFFFF)),
                                   ),
                                   child: CheckoutConfirmDialog(store: store, formatter: formatter),
                                ),
                              );
                              
                              if (result != null && result['ok'] == true) {
                                 final pm = store.paymentMethod;
                                 await store.checkout(
                                   customerName: result['name'] as String?,
                                   customerPhone: result['phone'] as String?,
                                   dueDate: result['dueDate'] as DateTime?,
                                 );
                                 if (!mounted) return;
                                 setState(() {
                                    _lastPaymentMethod = pm;
                                    _showSuccessPanel = true;
                                 });
                                 await Future.delayed(const Duration(milliseconds: 2000));
                                 if (!mounted) return;
                                 setState(() {
                                    _showSuccessPanel = false;
                                 });
                              }
                           },
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Text(
                                 store.checkouting ? 'Processing...' : 'Pay Now',
                                 style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                               ),
                               const SizedBox(width: 10),
                               const Icon(Icons.arrow_forward_rounded, size: 20),
                             ],
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTab(String label, String value, PosStore store) {
    final isActive = store.paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => store.setPaymentMethod(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF1f2d2e) : const Color(0xFF6B7A7B),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, bool strong) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          color: strong ? const Color(0xFF1f2d2e) : const Color(0xFF6B7A7B),
          fontSize: strong ? 22 : 14,
          fontWeight: strong ? FontWeight.bold : FontWeight.w500,
        )),
        Text(value, style: TextStyle(
          fontSize: strong ? 22 : 14,
          fontWeight: strong ? FontWeight.bold : FontWeight.w500,
          color: strong ? const Color(0xFF1E6F62) : const Color(0xFF1f2d2e),
        )),
      ],
    );
  }

  Widget _cartItemPlaceholder(String category) {
    return Center(
      child: Icon(Icons.local_cafe_rounded, size: 22, color: const Color(0xFF1E6F62).withOpacity(0.3)),
    );
  }
}
