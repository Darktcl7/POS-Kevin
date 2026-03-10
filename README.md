# POS Kevin

POS Tablet Android + Web Admin untuk coffee shop.

## Current Status (2026-03-04)
- Backend aktif: `backend_l12/` (Laravel 12 + Sanctum)
- Flutter app: `frontend/pos_tablet_app/`
- Migration POS + seeder awal sudah siap
- API core sudah aktif: auth, products, sales, purchase receive, printers, sync
- API dashboard sudah aktif: summary, sales trend, top products, low stock
- Flutter sudah punya fondasi offline: SQLite + sync queue + sync worker sederhana
- Web admin monitor tersedia di `http://localhost:8000/admin` (login via API token)

## Important Note
- Backend yang dipakai hanya `backend_l12/`.
- Binary PHP untuk Laravel 12:
`C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe`

## Quick Start Backend
```powershell
cd "d:\Laravel Project\POS Kevin\backend_l12"
copy .env.example .env
& 'C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe' artisan key:generate
& 'C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe' artisan migrate --seed
& 'C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe' artisan serve
```

Seed login awal:
- Email: `owner@poskevin.local`
- Password: `password123`

## Quick Start Flutter Tablet App
```powershell
cd frontend/pos_tablet_app
flutter pub get
flutter run -d android
```

## Docs
- `docs/architecture-pos-tablet.md`
- `docs/flowchart-mermaid.md`
- `docs/api-contract.md`
- `docs/NEXT-SESSION-HANDOVER.md`
