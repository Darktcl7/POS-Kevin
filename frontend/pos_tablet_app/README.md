# POS Tablet App

Flutter app untuk kasir tablet Android dengan target:
- Touch-friendly UI untuk kasir.
- Tetap bisa transaksi saat offline.
- Sync transaksi ke backend saat online.
- Siap integrasi printer struk Bluetooth/LAN/USB.

## Jalankan
```powershell
flutter pub get
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## Modul Saat Ini
- `lib/services/auth_service.dart`: login/logout/restore token Sanctum
- `lib/data/local/app_database.dart`: SQLite local cache + sync queue
- `lib/services/pos_service.dart`: checkout online/offline fallback
- `lib/services/sync_service.dart`: sync terjadwal + exponential backoff + dead-letter queue
- `lib/services/printer_service.dart`: print LAN/Bluetooth/USB (ESC/POS raw) + scan device Bluetooth/USB
- `lib/state/pos_store.dart`: state management + auto sync + retry dead-letter + filter/search/export log + reprint + export/share PDF invoice dari riwayat

## Next
- Tambah sinkronisasi held-order lintas device (opsional).
- Tambah filter tanggal log retry/void di web admin.
