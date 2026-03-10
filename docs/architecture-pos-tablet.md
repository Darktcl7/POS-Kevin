# POS Tablet Android Architecture

## Target
- Kasir jalan di Android tablet.
- Admin bisa dari tablet yang sama atau web browser.
- Satu outlet dulu, desain tetap siap multi outlet.
- Tetap bisa transaksi saat internet putus.
- Cetak struk via Bluetooth, LAN, USB.

## Stack
- Tablet App: Flutter (Android)
- Admin Web: Laravel Blade/Inertia (opsional fase 2)
- Backend API: Laravel + Sanctum
- DB Server: PostgreSQL (direkomendasikan)
- Cache/Queue: Redis (fase 2)
- Local Offline DB di tablet: SQLite

## High Level Components
1. Tablet App (Flutter)
- POS UI touch-friendly (tombol besar).
- Local SQLite untuk master data + pending transaction.
- Printer module ESC/POS: Bluetooth, TCP (LAN), USB.
- Sync worker background.

2. Backend API (Laravel)
- Auth token via Sanctum.
- Sales, purchase receiving, stock movement, recipes.
- Sync endpoints push/pull.
- Printer profile per outlet.

3. Admin Web
- Monitoring penjualan, stok, dan laporan.
- Bisa dari browser mana saja.

## Offline Strategy
- Semua transaksi kasir disimpan lokal dulu (SQLite) dengan status `PENDING_SYNC`.
- Jika online, transaksi langsung kirim API lalu status `SYNCED`.
- Jika offline, tetap cetak struk (asal printer terhubung lokal) dan antre ke outbox.
- Worker sync push antrean saat internet kembali.

## Printer Strategy
1. Bluetooth
- Cocok untuk kasir mobile.
- Simpan MAC address di tabel `printers.address`.

2. LAN
- Paling stabil untuk outlet tetap.
- Simpan IP di `printers.address`, port di `printers.port` (umumnya 9100).

3. USB
- Paling cepat dan stabil jika tablet support OTG.
- Simpan vendor/product id di `usb_vendor_id`, `usb_product_id`.

## Kiosk / Kasir Mode
- Fullscreen: aplikasi tanpa header browser/navigation.
- Lock app: screen pinning / dedicated device mode.
- UI touch-first: grid produk besar, tombol bayar besar, minim input keyboard.
