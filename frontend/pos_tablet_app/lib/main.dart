import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'data/local/app_database.dart';
import 'services/auth_service.dart';
import 'services/kiosk_service.dart';
import 'services/pos_service.dart';
import 'services/printer_service.dart';
import 'services/sync_service.dart';
import 'state/pos_store.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final database = AppDatabase.instance;

  final store = PosStore(
    authService: AuthService(apiClient: apiClient, database: database),
    posService: PosService(apiClient: apiClient, database: database),
    syncService: SyncService(apiClient: apiClient, database: database),
    printerService: PrinterService(database: database),
    kioskService: KioskService(),
  );

  runApp(PosTabletApp(store: store));
}

class PosTabletApp extends StatelessWidget {
  const PosTabletApp({super.key, required this.store});

  final PosStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final baseText = GoogleFonts.dmSansTextTheme();
        final production = store.tabletProductionMode;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'POS Kevin Tablet',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E6F62),
              brightness: Brightness.light,
            ),
            textTheme: baseText.copyWith(
              headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              bodyMedium: baseText.bodyMedium?.copyWith(height: 1.25),
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F1E8),
            cardTheme: CardThemeData(
              color: const Color(0xFFFFFFFF),
              shadowColor: const Color(0xFF1E6F62).withValues(alpha: 0.08),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              margin: EdgeInsets.zero,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF4F1E8),
              foregroundColor: Color(0xFF1f2d2e),
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF4F8F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD3DBDB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD3DBDB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1E6F62), width: 1.4),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(0, production ? 58 : 48),
                backgroundColor: const Color(0xFF1E6F62),
                foregroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, production ? 54 : 44),
                foregroundColor: const Color(0xFF1E6F62),
                side: BorderSide(color: const Color(0xFF1E6F62).withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          home: PosRootPage(store: store),
        );
      },
    );
  }
}

class PosRootPage extends StatefulWidget {
  const PosRootPage({super.key, required this.store});

  final PosStore store;

  @override
  State<PosRootPage> createState() => _PosRootPageState();
}

class _PosRootPageState extends State<PosRootPage> {
  @override
  void initState() {
    super.initState();
    widget.store.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (widget.store.loading && !widget.store.authenticated && widget.store.products.isEmpty) {
          return Scaffold(backgroundColor: const Color(0xFFF4F1E8), body: const Center(child: CircularProgressIndicator(color: Color(0xFF1E6F62))));
        }

        if (!widget.store.authenticated) {
          return LoginPage(store: widget.store);
        }

        return PosHomePage(store: widget.store);
      },
    );
  }
}

