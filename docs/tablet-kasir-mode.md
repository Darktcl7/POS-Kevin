# Tablet Kasir Mode (Penjelasan)

## Apa itu Mode Kasir Tablet?
Mode penggunaan khusus agar tablet dipakai seperti mesin kasir tetap.

## Komponen
- Fullscreen: app tampil layar penuh.
- Kiosk lock: kasir tidak keluar ke app lain.
- Touch-friendly: tombol besar, jarak antar tombol aman untuk jari.

## Implementasi Android
1. Gunakan Screen Pinning untuk level dasar.
2. Untuk outlet produksi, gunakan Dedicated Device / kiosk launcher.
3. Disable notifikasi yang mengganggu shift kasir.
4. Saat setup printer Bluetooth, grant permission runtime:
   - `BLUETOOTH_SCAN`
   - `BLUETOOTH_CONNECT`
   - `LOCATION` (beberapa device masih butuh untuk discovery).

## Implementasi di App Saat Ini
- App sudah pakai `immersiveSticky` (fullscreen).
- Di tab Admin ada kontrol:
  - `Aktifkan Kiosk` (start lock task)
  - `Matikan Kiosk` (stop lock task)
  - `Cek Status`

## Setup Produksi yang Disarankan
1. Aktifkan `Screen Pinning` di Android Settings.
2. Jalankan POS, lalu pin app (ikon pin di recent apps).
3. Untuk level enterprise, daftarkan app sebagai Dedicated Device/MDM policy.
