import 'package:flutter/material.dart';
import '../../state/pos_store.dart';
import 'package:intl/intl.dart';

class IngredientManagementTab extends StatefulWidget {
  const IngredientManagementTab({required this.store, required this.surfaceColor, required this.formatter});

  final PosStore store;
  final Color surfaceColor;
  final NumberFormat formatter;

  @override
  State<IngredientManagementTab> createState() => _IngredientManagementTabState();
}

class _IngredientManagementTabState extends State<IngredientManagementTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.store.loadIngredients();
    });
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final minStatusCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: const Text('Bahan Baku Baru', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Bahan Baku')),
              const SizedBox(height: 12),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Satuan (Gram, Pcs, dll)')),
              const SizedBox(height: 12),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Harga Modal / Satuan'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: minStatusCtrl, decoration: const InputDecoration(labelText: 'Peringatan Stok Minimum'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || unitCtrl.text.isEmpty || costCtrl.text.isEmpty || minStatusCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua field harus diisi')));
                return;
              }
              Navigator.pop(ctx);
              await widget.store.createIngredient({
                'ingredient_name': nameCtrl.text,
                'unit': unitCtrl.text,
                'cost_per_unit': int.parse(costCtrl.text),
                'minimum_stock': int.parse(minStatusCtrl.text),
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showUpdateStockDialog(Map<String, dynamic> item) {
    if (widget.store.warehousesList.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data gudang tidak tersedia')));
       return;
    }
    
    final qtyCtrl = TextEditingController();
    String? selectedWarehouseId = widget.store.warehousesList.first['id'].toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: widget.surfaceColor,
            title: Text('Update Stok: ${item['ingredient_name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Pilih Gudang / Lokasi'),
                  value: selectedWarehouseId,
                  items: widget.store.warehousesList.map((w) => DropdownMenuItem(value: w['id'].toString(), child: Text(w['warehouse_name']))).toList(),
                  onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  decoration: InputDecoration(labelText: 'Jumlah Penambahan (${item['unit']})'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                const Text('Tips: Gunakan minus (-) untuk mengurangi stok jika rusak/hilang', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  if (qtyCtrl.text.isEmpty || selectedWarehouseId == null) return;
                  Navigator.pop(ctx);
                  await widget.store.updateIngredientStock(item['id'], {
                    'warehouse_id': int.parse(selectedWarehouseId!),
                    'added_qty': int.parse(qtyCtrl.text),
                  });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
                },
                child: const Text('Perbarui'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _deleteIngredient(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: const Text('Hapus Bahan Baku?'),
        content: Text('Anda yakin ingin menghapus ${item['ingredient_name']}?'),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             onPressed: () async {
               Navigator.pop(ctx);
               await widget.store.deleteIngredient(item['id']);
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.store.status)));
             },
             child: const Text('Hapus', style: TextStyle(color: Colors.white)),
           ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bahan Baku & Stok', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1f2d2e))),
              Row(
                children: [
                  IconButton(
                    onPressed: () => widget.store.loadIngredients(),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Bahan Baru'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.store.ingredientsLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (widget.store.ingredientsList.isEmpty)
          const Expanded(child: Center(child: Text('Tidak ada data bahan baku', style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: widget.store.ingredientsList.length,
              itemBuilder: (context, index) {
                final item = widget.store.ingredientsList[index];
                final totalStock = item['total_stock'] ?? 0;
                final minStock = item['minimum_stock'] ?? 0;
                final isLow = totalStock <= minStock;
                
                return Card(
                  color: widget.surfaceColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                           backgroundColor: isLow ? Colors.red.withOpacity(0.1) : const Color(0xFF1E6F62).withOpacity(0.1),
                           child: Icon(Icons.inventory_2_outlined, color: isLow ? Colors.red : const Color(0xFF1E6F62)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['ingredient_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Modal: ${widget.formatter.format(num.parse(item['cost_per_unit'].toString()))} / ${item['unit']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$totalStock ${item['unit']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLow ? Colors.red : Colors.green)),
                            Text('Tersedia', style: TextStyle(color: isLow ? Colors.red : Colors.green, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (val) async {
                            if (val == 'stock') {
                              _showUpdateStockDialog(item);
                            } else if (val == 'delete') {
                              _deleteIngredient(item);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'stock', child: Text('Update / Sesuaikan Stok')),
                            const PopupMenuItem(value: 'delete', child: Text('Hapus Bahan Baku', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
