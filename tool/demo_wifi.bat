@echo off
rem Klik dua kali: build Flutter web bila kode berubah, lalu sajikan ke HP lewat WiFi yang sama.
rem Tutup jendela ini (atau Ctrl+C) untuk berhenti. Tambahan argumen diteruskan, mis. demo_wifi.bat --build
cd /d "%~dp0.."
node tool\demo_wifi.mjs %*
pause
