# Menjalankan Aplikasi POS Kevin (Backend + Web Admin + Flutter Tablet)

Dokumen ini adalah panduan cepat untuk menjalankan sistem POS Kevin pada lokal development.

---

## 1. Kebutuhan Minimum

- Windows + PowerShell
- PHP 8.3 (path lengkap, bukan XAMPP)
- Composer
- Flutter SDK
- LDPlayer (emulator Android) atau HP/Tablet fisik
- SQLite (sudah built-in, tidak perlu XAMPP MySQL)

## 2. Struktur Folder Project

| Komponen | Path |
|---|---|
| Backend Laravel + Web Admin | `D:\Laravel Project\POS Kevin\backend_l12` |
| Flutter Tablet App | `D:\Laravel Project\POS Kevin\frontend\pos_tablet_app` |
| Database SQLite | `D:\Laravel Project\POS Kevin\backend_l12\database\database.sqlite` |

## 3. IP Laptop Saat Ini

```
192.168.100.4
```

> ⚠️ IP ini bisa berubah kalau ganti Wi-Fi. Cek ulang dengan: `ipconfig | Select-String "IPv4"`

---

## 4. Cara Jalankan (Copy-Paste)

### Terminal 1 — Backend Laravel (API + Web Admin)

```powershell
cd "D:\Laravel Project\POS Kevin\backend_l12"
& "C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe" artisan serve --host=0.0.0.0 --port=8000
```

Tunggu sampai muncul hijau: `Server running on [http://0.0.0.0:8000]`

Setelah menyala:
- **Web Admin Dashboard**: http://127.0.0.1:8000/pos
- **Backend API**: http://127.0.0.1:8000/api

---

### Terminal 2 — Flutter Tablet App di LDPlayer

```powershell
cd "D:\Laravel Project\POS Kevin\frontend\pos_tablet_app"
adb connect localhost:5555
flutter run -d emulator-5554 --release --dart-define=API_BASE_URL=http://192.168.100.4:8000/api
```

> Kalau diminta pilih device, ketik `1` lalu Enter.

---

### Terminal 2 (Alternatif) — Flutter di HP/Tablet Fisik via USB

```powershell
cd "D:\Laravel Project\POS Kevin\frontend\pos_tablet_app"
flutter run --release --dart-define=API_BASE_URL=http://192.168.100.4:8000/api
```

---

## 5. Build APK (Untuk Install Manual / Drag & Drop ke Emulator)

```powershell
cd "D:\Laravel Project\POS Kevin\frontend\pos_tablet_app"
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.100.4:8000/api
```

Hasil APK ada di:
```
D:\Laravel Project\POS Kevin\frontend\pos_tablet_app\build\app\outputs\flutter-apk\app-release.apk
```

Drag & drop file APK tersebut ke LDPlayer untuk install.

---

## 6. Build & Deploy Web Admin (Setelah Edit Kode Flutter)

```powershell
cd "D:\Laravel Project\POS Kevin\frontend\pos_tablet_app"
flutter build web --release --dart-define=API_BASE_URL=/api
```

Lalu deploy ke backend:
```powershell
Remove-Item -Recurse -Force "D:\Laravel Project\POS Kevin\backend_l12\public\pos\*"
Copy-Item -Recurse -Force "build\web\*" "D:\Laravel Project\POS Kevin\backend_l12\public\pos\"
```

Terakhir edit file `D:\Laravel Project\POS Kevin\backend_l12\public\pos\index.html`:
- Cari: `<base href="/">`
- Ganti menjadi: `<base href="/pos/">`

---

## 7. Login Default

| Email | Password | Role | Akses |
|---|---|---|---|
| `owner@poskevin.local` | `password123` | Owner | Web Admin + Tablet (semua fitur) |

> Web Admin hanya bisa diakses oleh Owner/Manager. Kasir hanya login di Tablet.

---

## 8. Perbedaan Web vs Tablet

| Fitur | Web Admin | Tablet App |
|---|---|---|
| POS Kasir (transaksi) | ❌ | ✅ |
| Admin Dashboard | ✅ | ✅ |
| Kelola Produk + Harga Modal | ✅ | ✅ |
| Kelola User | ✅ | ✅ |
| Bahan Baku / Stok | ✅ | ✅ |
| Printer (cetak struk) | ❌ | ✅ |
| Offline Mode | ❌ | ✅ |

---

## 9. Troubleshooting

### 9.1 Error: "require PHP >= 8.2"
Terminal masih pakai PHP XAMPP lama. Selalu gunakan path lengkap PHP 8.3:
```powershell
& "C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe" artisan serve --host=0.0.0.0 --port=8000
```

### 9.2 Tablet tidak bisa konek / "Connection Timed Out"
1. Pastikan backend sudah jalan dengan `--host=0.0.0.0`
2. Pastikan IP laptop benar (cek `ipconfig`)
3. Buka firewall port 8000 (jalankan di PowerShell **Admin**):
```powershell
netsh advfirewall firewall add rule name="Laravel POS" dir=in action=allow protocol=TCP localport=8000
```
4. Pastikan laptop & tablet/emulator dalam 1 jaringan

### 9.3 Web Admin kosong / blank setelah update
Rebuild dan deploy ulang (lihat Bagian 6 di atas), jangan lupa ubah `<base href>`.

### 9.4 Produk tablet tidak sinkron dengan website
Klik tombol **🔄 Refresh** di Admin Dashboard, atau buka ulang tab **Produk**. Tablet akan otomatis mengambil data terbaru dari server.

### 9.5 Database Migration (menambah kolom baru)
```powershell
cd "D:\Laravel Project\POS Kevin\backend_l12"
& "C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe" artisan migrate
```
