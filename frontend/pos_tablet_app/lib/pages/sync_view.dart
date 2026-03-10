import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/pos_store.dart';
import '../core/config/app_config.dart';
import '../widgets/shared_widgets.dart';

class SyncView extends StatefulWidget {
  const SyncView({required this.store});

  final PosStore store;

  @override
  State<SyncView> createState() => SyncViewState();
}

class SyncViewState extends State<SyncView> {
  late final TextEditingController _searchController;

  Widget _syncChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.store.syncSearchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final dateFmt = DateFormat('dd/MM HH:mm:ss');

    Color statusColor(String status) {
      switch (status) {
        case 'SYNCED':
          return Colors.green.shade700;
        case 'FAILED_PERMANENT':
          return Colors.red.shade700;
        default:
          return Colors.orange.shade800;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E6F62), Color(0xFF3aa69b)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E6F62).withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline & Sync Queue',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _syncChip('Pending ${store.pendingSyncCount}'),
                    _syncChip('Dead ${store.deadLetterSyncCount}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E6F62).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_sync, color: Color(0xFF1E6F62)),
              ),
              title: const Text('Pending Queue'),
              subtitle: Text('${store.pendingSyncCount} transaksi menunggu sinkronisasi'),
              trailing: ElevatedButton(
                onPressed: store.syncing ? null : store.syncNow,
                child: Text(store.syncing ? 'Syncing...' : 'Sync Now'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              title: Text('Failed permanen: ${store.deadLetterSyncCount}'),
              subtitle: const Text('Data gagal permanen bisa dipindah lagi ke antrean sync.'),
              trailing: OutlinedButton(
                onPressed: store.deadLetterSyncCount > 0 ? store.retryAllDeadLetters : null,
                child: const Text('Retry All'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (store.deadLetterItems.isEmpty)
            const EmptyStateCard(
              icon: Icons.check_circle_outline,
              title: 'Tidak ada dead letter',
              subtitle: 'Semua queue bermasalah sudah dibersihkan.',
            )
          else
            ...store.deadLetterItems.take(20).map(
                  (item) => Card(
                    child: ListTile(
                      title: Text('${item.entityType} ${item.operation} #${item.id}'),
                      subtitle: Text(
                        item.lastError?.isNotEmpty == true ? item.lastError! : 'No error detail',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => store.retryDeadLetterItem(item.id),
                        child: const Text('Retry'),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          const Text('Riwayat Sync Terbaru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: store.syncStatusFilter,
                  decoration: const InputDecoration(labelText: 'Filter Status'),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('ALL')),
                    DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                    DropdownMenuItem(value: 'SYNCED', child: Text('SYNCED')),
                    DropdownMenuItem(value: 'FAILED_PERMANENT', child: Text('FAILED_PERMANENT')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    store.setSyncStatusFilter(value);
                  },
                ),
              ),
              SizedBox(
                width: 360,
                child: TextField(
                  controller: _searchController,
                  onChanged: store.setSyncSearchQuery,
                  decoration: const InputDecoration(
                    labelText: 'Cari (id/entity/status/error)',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await store.exportFilteredSyncLogsCsv();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export gagal: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (store.filteredSyncItems.isEmpty)
            const EmptyStateCard(
              icon: Icons.filter_alt_off,
              title: 'Tidak ada data sync sesuai filter',
              subtitle: 'Ubah filter status atau keyword pencarian.',
            )
          else
            ...store.filteredSyncItems.take(50).map(
                  (item) => Card(
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text('${item.entityType} ${item.operation} #${item.id}')),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor(item.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(color: statusColor(item.status), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'retry=${item.retryCount} | created=${dateFmt.format(item.createdAt)} | '
                        'next=${dateFmt.format(item.nextRetryAt)}'
                        '${item.syncedAt != null ? ' | synced=${dateFmt.format(item.syncedAt!)}' : ''}'
                        '${item.lastError?.isNotEmpty == true ? '\nerror=${item.lastError}' : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
