# Build web release sekali jalan: build Flutter dengan alamat API relatif,
# buang font shadcn yang tidak terpakai, lalu periksa main.dart.js.
# Jalankan dari PowerShell (dari folder mana pun):
#   powershell -ExecutionPolicy Bypass -File tool\build_web.ps1
# Gagal (exit 1) bila salah satu langkah gagal atau hasil build tidak sesuai.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

# 1. Build web dengan alamat API relatif.
flutter build web --release --dart-define=API_BASE_URL=/api/v1
if ($LASTEXITCODE -ne 0) { Write-Error 'flutter build web gagal.'; exit 1 }

# 2. Buang font Lucide dan Geist yang tidak terpakai.
dart run tool/strip_unused_web_fonts.dart
if ($LASTEXITCODE -ne 0) { Write-Error 'Skrip pembuang font gagal.'; exit 1 }

# 3. Pastikan alamat API benar: harus "/api/v1", bukan path Windows hasil
#    konversi Git Bash (mis. "C:/Program Files/Git/api/v1").
$mainJs = Get-Content 'build\web\main.dart.js' -Raw
if (-not $mainJs.Contains('/api/v1')) {
  Write-Error 'main.dart.js tidak memuat "/api/v1".'; exit 1
}
if ($mainJs.Contains('Program Files')) {
  Write-Error 'main.dart.js memuat "Program Files": API_BASE_URL rusak.'; exit 1
}
Write-Host 'Build web siap di build\web (API /api/v1, font tidak terpakai sudah dibuang).'
