# Seed toko demo ke production

`tool/seed_toko.dart` membuat 5 toko demo aplikasi mobile (Diego Katering,
Martabak Pecenongan, Dapur Slamet, Surgawi Bakery, Dapur Bu Tima) beserta menunya
sebagai data NYATA di backend KateringKita lewat REST API publiknya. Data sumber
ada di `tool/seed_toko.json` (berasal dari `lib/models/vendor_model.dart`).

Per toko skrip: login penjual (bila belum ada, daftar), verifikasi oleh admin,
atur profil (jam buka, titik ambil 1-3, hold 30 menit, deskripsi, logo), unggah
gambar ke R2 lewat `POST /merchant/uploads`, lalu membuat menu.

## Prasyarat

- Penyimpanan R2 sudah dikonfigurasi di Heroku (tanpa itu unggah gambar gagal).
- Akun admin yang bisa login dengan client `web`.
- Jalankan dari root repo (skrip membaca `tool/seed_toko.json` dan `assets/images/`).

## Cara menjalankan

```
dart run tool/seed_toko.dart
dart run tool/seed_toko.dart --api https://host/api/v1   # URL lain (opsional)
```

Skrip meminta lewat terminal: identitas + sandi admin (tanpa gema), lalu per toko
no HP penjual (bawaan dari JSON, bisa Enter) dan sandi penjual (8-72 karakter,
minimal satu huruf dan satu angka). Kredensial hanya hidup di memori, tidak pernah
ditulis ke berkas.

## Idempoten

Aman dijalankan ulang: penjual yang sudah ada hanya login, verifikasi dilewati bila
sudah `verified`, menu yang namanya sudah ada dilewati. Gunakan sandi penjual yang
sama saat menjalankan ulang. Logo diunggah ulang tiap jalan (profil diperbarui).

## Tes

`flutter test test/tool` (fungsi murni di `tool/seed_lib.dart` + validasi JSON; tanpa jaringan).

# Demo di HP lewat WiFi yang sama

`tool/demo_wifi.mjs` menyajikan aplikasi versi web ke HP yang tersambung ke WiFi yang sama
dengan laptop. API diteruskan ke backend production dari alamat yang sama, jadi tidak ada
masalah CORS dan foto menu tetap tampil.

```
node tool/demo_wifi.mjs           # build dulu bila build/web belum ada, lalu sajikan
node tool/demo_wifi.mjs --build   # build ulang (setelah kode berubah), lalu sajikan
```

Terminal mencetak alamat untuk dibuka di HP, mis. `http://192.168.100.218:8080`.
Build memakai `API_BASE_URL=/api/v1` (relatif), jadi saat IP WiFi berubah cukup jalankan
ulang skrip tanpa build ulang. Bila HP tidak bisa membuka alamatnya: izinkan Node.js di
Windows Firewall, atau pakai hotspot HP (sebagian WiFi publik memblokir antar-perangkat).

Beranda hanya menampilkan menu dari toko yang sedang buka (jam buka WIB di Pengaturan toko).
