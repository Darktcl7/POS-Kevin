@echo off
color 0B
echo =======================================================
echo          POS KEVIN - STARTUP SCRIPT (WEB & API)
echo =======================================================
echo.
echo Script ini akan menjalankan Backend API dan Frontend Web POS.
echo Pastikan XAMPP (MySQL) sudah menyala sebelum melanjutkan.
echo.
pause

echo.
echo [1/2] Memulai Server Backend di Port 8000...
cd "D:\Laravel Project\POS Kevin\backend_l12"

:: Ini akan membuka jendela terminal baru (hitam) khusus untuk server
start "POS Server (JANGAN DITUTUP)" cmd /c ""C:\Users\chlui\AppData\Local\Microsoft\WinGet\Packages\PHP.PHP.8.3_Microsoft.Winget.Source_8wekyb3d8bbwe\php.exe" artisan serve --host=0.0.0.0 --port=8000"

echo.
echo [2/2] Menyiapkan dan membuka Web POS di Browser...
:: Menunggu 3 detik agar server sempat hidup sepenuhnya
timeout /t 3 >nul

:: Membuka Google Chrome langsung ke URL /pos
start http://127.0.0.1:8000/pos

echo.
echo =======================================================
echo ✅ SELESAI!
echo =======================================================
echo - POS Admin/Kasir Web: http://127.0.0.1:8000/pos
echo - Backend API: http://127.0.0.1:8000/api
echo.
echo Catatan: 
echo - Biarkan jendela hitam "POS Server" tetap terbuka selama aplikasi digunakan.
echo - Untuk menjalankan Aplikasi Tablet (Android), gunakan ikon aplikasi di LDPlayer.
echo.
pause
