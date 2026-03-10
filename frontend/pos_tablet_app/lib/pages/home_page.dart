import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../state/pos_store.dart';
import '../core/config/app_config.dart';
import 'cashier_view.dart';
import 'admin_view.dart';
import 'sync_view.dart';
import 'settings_view.dart';

class PosHomePage extends StatefulWidget {
  const PosHomePage({required this.store});

  final PosStore store;

  @override
  State<PosHomePage> createState() => PosHomePageState();
}

class PosHomePageState extends State<PosHomePage> {
  int tabIndex = kIsWeb ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      kIsWeb ? const Center(child: Text('Fitur Kasir POS hanya tersedia di Aplikasi Tablet Android.')) : CashierView(store: widget.store),
      AdminView(store: widget.store),
      SyncView(store: widget.store),
      SettingsView(store: widget.store),
    ];
    final syncAlerts = widget.store.pendingSyncCount + widget.store.deadLetterSyncCount;
    final adminAlerts = widget.store.failedHistoryCount;

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F1E8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E6F62),
          surface: Color(0xFFFFFFFF),
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.light().textTheme),
      ),
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                border: Border(right: BorderSide(color: Color(0xFFD3DBDB))),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E6F62), Color(0xFF3aa69b)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('K', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 32),
                  // Nav Items
                  if (!kIsWeb)
                    _buildNavItem(Icons.grid_view_rounded, 0, false),
                  if (widget.store.isAdmin) ...[
                    _buildNavItem(Icons.admin_panel_settings, 1, adminAlerts > 0),
                    if (!kIsWeb) _buildNavItem(Icons.sync_rounded, 2, syncAlerts > 0),
                  ],
                  const Spacer(),
                  _buildNavItem(Icons.settings, 3, false), 
                  const SizedBox(height: 16),
                  const CircleAvatar(
                    backgroundColor: Color(0xFF1E6F62),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Container(width: 1, color: const Color(0xFFD3DBDB)),
            // Main Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(tabIndex),
                  child: tabIndex < pages.length ? pages[tabIndex] : Container(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, bool hasAlert) {
    final isActive = tabIndex == index;
    return GestureDetector(
      onTap: () {
         setState(() => tabIndex = index);
      },
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E6F62) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive ? [BoxShadow(color: const Color(0xFF1E6F62).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
             Icon(icon, color: isActive ? const Color(0xFFFFFFFF) : const Color(0xFF6B7A7B), size: 28),
             if (hasAlert)
               Positioned(
                 top: 12, right: 12,
                 child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
               ),
          ],
        ),
      ),
    );
  }
}
