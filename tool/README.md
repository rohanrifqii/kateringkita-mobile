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
