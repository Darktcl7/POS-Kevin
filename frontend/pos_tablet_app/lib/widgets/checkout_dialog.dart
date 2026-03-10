import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/pos_store.dart';
import '../core/config/app_config.dart';

class CheckoutConfirmDialog extends StatefulWidget {
  const CheckoutConfirmDialog({required this.store, required this.formatter});

  final PosStore store;
  final NumberFormat formatter;

  @override
  State<CheckoutConfirmDialog> createState() => _CheckoutConfirmDialogState();
}

class _CheckoutConfirmDialogState extends State<CheckoutConfirmDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '7');

  @override
  Widget build(BuildContext context) {
    final remaining = widget.store.cart.length - 8;
    final isTempo = widget.store.paymentMethod == 'TEMPO';

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFFFF),
      title: const Text('Konfirmasi Pembayaran', style: TextStyle(color: Color(0xFF1F2D2E), fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.payments, size: 16),
                    label: Text(widget.store.paymentMethod),
                  ),
                  Chip(
                    avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
                    label: Text('${widget.store.cart.length} item'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...widget.store.cart.take(8).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.product.productName} x${item.quantity}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(widget.formatter.format(item.subtotal)),
                        ],
                      ),
                    ),
                  ),
              if (remaining > 0)
                Text(
                  '+$remaining item lainnya',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E99),
                  ),
                ),
              const Divider(height: 18),
              DialogSummaryRow(label: 'Total', value: widget.formatter.format(widget.store.cartTotal), strong: true),
              if (widget.store.isCashPayment) ...[
                const SizedBox(height: 4),
                DialogSummaryRow(
                  label: 'Tunai',
                  value: widget.formatter.format(widget.store.cashReceivedAmount),
                ),
                const SizedBox(height: 4),
                DialogSummaryRow(
                  label: 'Kembalian',
                  value: widget.formatter.format(widget.store.cashChangeAmount),
                ),
              ] else if (isTempo) ...[
                const SizedBox(height: 16),
                const Text('Data Penagihan Tempo', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E6F62))),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Pelanggan', filled: true, fillColor: Color(0xFF2A2A32)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'No WhatsApp (Cth: 62812...)', filled: true, fillColor: Color(0xFF2A2A32)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Lama Tempo (Hari)', filled: true, fillColor: Color(0xFF2A2A32)),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6F62).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E6F62).withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, size: 32, color: Color(0xFF1E6F62)),
                      const SizedBox(height: 8),
                      Text(
                        widget.store.paymentMethod == 'QRIS' 
                          ? 'Pastikan pelanggan sudah scan dan berhasil membayar melalui QRIS Toko (Standee) sebelum menyimpan transaksi ini.'
                          : 'Pembayaran non-tunai akan langsung ditandai lunas.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E6F62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (isTempo) {
              if (_nameCtrl.text.isEmpty || _daysCtrl.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama & Lama Tempo wajib diisi')));
                 return;
              }
              final days = int.tryParse(_daysCtrl.text) ?? 0;
              final dueDate = DateTime.now().add(Duration(days: days));
              Navigator.of(context).pop({
                'ok': true,
                'name': _nameCtrl.text,
                'phone': _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
                'dueDate': dueDate,
              });
            } else {
              Navigator.of(context).pop({'ok': true});
            }
          },
          icon: const Icon(Icons.check_circle_outline),
          label: Text(isTempo ? 'Simpan Tagihan' : 'Bayar Sekarang'),
        ),
      ],
    );
  }
}

class DialogSummaryRow extends StatelessWidget {
  const DialogSummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: strong ? 16 : 14,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
      color: const Color(0xFFFCFCFC),
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
