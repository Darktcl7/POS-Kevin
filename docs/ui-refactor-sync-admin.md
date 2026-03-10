# Refaktorisasi UI: Tema Light (Putih-Hijau)

Dokumen ini mencatat transisi dan refaktorisasi antarmuka (UI) dari tema gelap (Dark Theme / Coffee) ke tema terang (Light Theme / Teal Green) yang diterapkan pada **Admin Web Dashboard (Laravel)** dan **Aplikasi Kasir Tablet (Flutter)**.

## 1. Skema Warna (Color Palette)

Skema warna baru difokuskan pada kebersihan (cleanliness), kontras yang nyaman dimata, dan warna aksen hijau toska (teal green) yang segar.

- **Background (bg)**: `#F4F1E8` (Beige / Krem Terang)
- **Surface (Card/Box)**: `#FFFFFF` (Putih Murni)
- **Primary Accent / Brand**: `#1E6F62` (Teal Green / Hijau Toska)
- **Secondary Accent (Hover/Gradient)**: `#3aa69b` (Hijau Toska Terang)
- **Text (Ink)**: `#1F2D2E` (Abu-abu Gelap / Charcoal)
- **Muted Text / Icons**: `#6B7A7B` (Abu-abu Menengah)
- **Border / Line**: `#D3DBDB` (Abu-abu Terang)
- **Success / Valid**: `#027a48` (Hijau Sukses)
- **Warning / Alert**: `#b54708` (Oranye Gelap)
- **Danger / Error**: `#ef4444` (Merah Redup)

---

## 2. Perubahan pada Frontend (Flutter Tablet App)

Semua perbaikan telah diaplikasikan pada keseluruhan komponen tablet, menggantikan warna lama `0xFF1A1A20` dan `0xFFC98A58`.

### File yang Diperbarui:
1. **`lib/main.dart`**
   - Mengganti `ThemeData` agar menggunakan `ColorScheme.light`.
   - Menyesuaikan `scaffoldBackgroundColor` menjadi `0xFFF4F1E8`.
   - Menyesuaikan komponen `CardTheme`, `InputDecorationTheme`, dan `ElevatedButtonThemeData`.
   - Memastikan `CircularProgressIndicator` di tahap *loading awal* (sebelum login/fetch data) menggunakan warna hijau `0xFF1E6F62`.

2. **`lib/pages/login_page.dart`**
   - Penyesuaian `backgroundColor` Scaffold.
   - Penggantian accent circle gradient background (animasi lingkaran di belakang).
   - Pengubahan warna border input TextField, icon email/password, dan warna button Login.

3. **`lib/pages/cashier_view.dart` & `lib/pages/home_page.dart`**
   - Menata ulang warna background drawer (sidebar), keranjang (cart), list kategori, dan background form kasir utama.
   - Penyesuaian indicator item yang low stock dan kosong.

4. **`lib/pages/admin_view.dart` & `lib/pages/sync_view.dart`**
   - Mengganti semua container warna `0xFF1A1A20` menjadi `0xFFFFFFFF` (Card putih).
   - Mengganti warna button tambah produk, icon sinkronisasi, dan gradien header "Offline & Sync Queue" serta "Admin Dashboard" dari gradien coklat-kopi menjadi linear gradient hijau (`0xFF1E6F62` ke `0xFF3aa69b`).

5. **`lib/widgets/shared_widgets.dart` & `lib/widgets/checkout_dialog.dart`**
   - Modal Konfirmasi Pembayaran dan Tempo telah sepenuhnya dibuat terang dengan background putih dan warna tagihan tempo menjadi hijau.

---

## 3. Perubahan pada Backend (Laravel Admin Dashboard)

Admin Panel Web yang diakses via browser juga diseragamkan warnanya agar senada dengan tablet POS.

### File yang Diperbarui (`resources/views/admin/*`):
1. **`dashboard.blade.php` (Monitor Utama)**
2. **`ingredients/index.blade.php` (Bahan Baku & Stok)**
3. **`products/index.blade.php` (Katalog Produk)**

**Implementasi CSS:**
Perubahan utama terjadi pada deklarasi CSS Variables di awal tag `<style>:root` pada tiap file Blade:
```css
:root {
    --bg: #F4F1E8;
    --surface: #ffffff;
    --ink: #1f2d2e;
    --accent: #1E6F62;
    --muted: #6B7A7B;
    --danger: #ef4444;
    --warn: #b54708;
    --ok: #027a48;
    --line: #D3DBDB;
}
```
Gradien tombol dan progress bar juga telah disesuaikan agar menggunakan warna `--accent` dan fallback fallback hijau muda `#3aa69b`.

---

## 4. Rencana / Next Steps (Sesi Berikutnya)
- Menguji coba seluruh *flow* penjualan offline dan sinkronisasi ke server dengan UI yang baru.
- Memastikan print thermal berjalan dengan baik (karena tablet dicolokkan ke Printer/Cash Drawer).
- Penambahan / Refined Fitur Katalog jika masih ada komponen UX yang dirasa kurang pas setelah testing lapangan.
