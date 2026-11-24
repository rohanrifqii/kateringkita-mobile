# 🍱 KateringKita Mobile (Flutter App)

Halo tim **KateringKita** (Abdurrahim, Rohan, Diego, Ammar)! 👋  
Ini adalah *repository* aplikasi **Mobile KateringKita** (Flutter). Supaya waktu kalian *clone* atau *pull* project ini di laptop masing-masing **nggak kena drama error beda versi, gagal build, atau layar merah**, tolong baca panduan santai di bawah ini secara urut ya!

## 📱 Tentang aplikasi

Aplikasi pembeli KateringKita (Android dan web). Semua data dan aturan bisnis lewat [backend REST API](https://github.com/stanlevv/kateringkita-backend); aplikasi tidak menyentuh database, Midtrans, atau penyedia AI secara langsung. Diagram arsitektur seluruh sistem ada di README backend.

| Fitur | Layar |
|---|---|
| Daftar, masuk, lupa sandi (OTP email) | `screens/auth/` |
| Beranda, cari, detail menu, profil toko, banner & pop-up promo | `screens/home/` |
| Keranjang & checkout (titik temu, voucher toko + platform), bayar tunai / VA / online (Midtrans) | `screens/orders/` |
| Pesanan aktif & selesai, status langsung, pesan lagi, ulasan, chat WhatsApp ke penjual | `screens/orders/` |
| Favorit menu & toko, notifikasi | `screens/liked/`, `screens/home/` |
| Asisten AI & rekomendasi menu | `screens/ai/` |
| Profil, Voucher Saya, tiket bantuan ke tim KateringKita | `screens/profile/`, `screens/support/` |

---

## 🛠️ 1. Spesifikasi Versi yang Dipakai (Wajib Cek Dulu!)

Sering banget kejadian di Flutter: *"Loh, di laptopku jalan kok, kenapa di laptopmu merah semua?"* — **99% penyebabnya karena versi Flutter/Dart atau Java di laptop kalian belum di-update.**

Project ini dibangun dan dites menggunakan versi berikut:
- **Flutter SDK:** `3.47.x` (Channel `stable` — minimal `3.47.0+`)
- **Dart SDK:** `^3.13.4` (otomatis ikut ter-install bareng Flutter)
- **JDK / Java:** `Java 17` (Bawaan langsung dari Android Studio terbaru / *JetBrains Runtime*)
- **Gradle Wrapper:** `9.3.1` (Otomatis ke-download sendiri waktu pertama kali *run*, nggak perlu install manual)
- **Android Gradle Plugin (AGP):** `9.1.0` & **Kotlin:** `2.4.0`

### 🔍 Cara Cek Versi di Laptopmu
Buka terminal (CMD / PowerShell / Terminal VS Code), lalu ketik:
```bash
flutter --version
```
> **⚠️ PENTING:** Kalau versi **Dart** kamu masih di bawah `3.13.4` (misalnya masih `3.5.x` atau `3.10.x`), kamu **WAJIB** update dulu cukup dengan ketik perintah ini di terminal:
> ```bash
> flutter channel stable
> flutter upgrade
> ```
> Tunggu sampai proses *upgrade* selesai, baru lanjut ke langkah di bawah.

---

## 🚀 2. Cara Menjalankan Project (Step-by-Step dari Nol)

Ikuti langkah ini secara urut waktu baru selesai `git clone` atau `git pull`:

### Langkah 1: Clone & Masuk ke Folder Project
```bash
git clone https://github.com/rohanrifqii/kateringkita-mobile.git
cd kateringkita-mobile
```
*(Kalau kamu udah pernah clone sebelumnya, cukup ketik `git pull origin main` di dalam folder `kateringkita-mobile`).*

### Langkah 2: Ambil Semua Package (Dependencies)
Jangan pakai perintah aneh-aneh, cukup ketik:
```bash
flutter pub get
```
Perintah ini bakal mengambil semua *library* sesuai versi yang udah dikunci di `pubspec.lock`.

### Langkah 3: Nyalakan Emulator atau Colok HP Android
- **Pakai HP Fisik (Paling Disarankan & Ringan):** Aktifkan *Developer Options* & *USB Debugging* di HP Android kamu, lalu colok kabel data ke laptop.
- **Pakai Emulator Android Studio:** Buka *Virtual Device Manager* di Android Studio, lalu nyalakan emulatornya.
- Pastikan perangkatmu terdeteksi dengan ketik:
  ```bash
  flutter devices
  ```

### Langkah 4: Jalankan Aplikasi!
Ketik perintah ini di terminal:
```bash
flutter run
```
> **💡 Catatan Pertama Kali Run:** Waktu pertama kali banget kamu jalanin `flutter run`, Gradle bakal men-download *dependencies* Android di belakang layar. Kalau internet agak pelan, proses pertama ini bisa makan waktu **3–8 menit**. Jangan panik dan **jangan di-close paksa** terminalnya ya, tunggu aja sampai selesai. Run kedua dan seterusnya bakal ngebut!

### Build APK release (untuk dibagikan)
ID aplikasi: `id.kateringkita.app`. APK resmi ditandatangani kunci release dari `android/key.properties`:
1. Minta file keystore (`.jks`) dan `key.properties` ke pemegang kunci rilis. **Jangan pernah di-commit** (sudah di `.gitignore`).
2. Taruh `key.properties` di folder `android/` (format: lihat `android/key.properties.example`).
3. Build:
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://ketring-45f82aef1ca0.herokuapp.com/api/v1
   ```
   Hasilnya di `build/app/outputs/flutter-apk/app-release.apk`.

Tanpa `key.properties`, build release tetap jalan tetapi memakai kunci debug. APK seperti itu tidak bisa memperbarui APK resmi yang sudah terpasang di HP.

---

## 🚫 3. Apa yang JANGAN Diubah / Disentuh Tanpa Koordinasi!

Supaya kodingan kita nggak bentrok (*conflict*) atau bikin error di laptop teman lain, **tolong jangan ubah file-file ini kecuali memang tugasmu:**

1. ❌ **Jangan jalanin `flutter pub upgrade --major-versions`**
   - Kita udah ngunci kombinasi versi package yang paling stabil di `pubspec.yaml` dan `pubspec.lock`. Kalau kamu paksa *upgrade major versions*, beberapa package bisa nggak kompatibel satu sama lain. Cukup pakai **`flutter pub get`** aja!
2. ❌ **Jangan utak-atik versi di `android/settings.gradle.kts`, `android/app/build.gradle.kts`, atau `gradle-wrapper.properties`**
   - Versi Java 17, Kotlin 2.4.0, dan Gradle 9.3.1 di sana udah disetel pas dengan Flutter terbaru.
3. ❌ **Jangan commit folder `build/`, `.dart_tool/`, atau file `android/local.properties`**
   - File `local.properties` itu isinya lokasi SDK di laptop masing-masing (beda laptop beda lokasi). File itu udah masuk di `.gitignore` dan bakal dibuat otomatis sama Flutter di laptopmu.

---

## 🧠 4. Info Penting Buat Tim (Diego, Ammar, & Rohan)

Supaya kalian paham cara kerja fitur-fitur yang udah jalan di Mobile saat ini:

### 🗺️ A. Titik Temu & Peta (`pickup_point_picker_screen.dart` & `lib/services/map_service.dart`)
- **Tidak ada pengantaran.** Pembeli mengambil sendiri pesanannya di **titik temu** kampus. Daftar titik temu dari backend (`GET /meta/pickup-points`), tanpa koordinat, jadi peta `flutter_map` + OpenStreetMap hanya jadi **latar** area kampus (tanpa API key, tanpa GPS).
- Di beranda, pembeli memilih **titik temu favorit**; pilihannya disimpan ke profil lewat `PATCH /me` (`favorite_pickup_point_id`) dan otomatis dipilih saat checkout bila titik itu dilayani toko.

### 🤖 B. Fitur AI Assistant (`lib/data/assistant_repository.dart` & `ai_assistant_screen.dart`)
- AI Assistant memanggil **backend** (`POST /assistant/recommendations`), **bukan** Gemini langsung. Aplikasi tidak menyimpan API key AI apa pun; kunci, pilihan model, dan kuota diatur di server.
- Pembeli (harus login) menulis kebutuhan, opsional anggaran, jumlah porsi, dan kategori. Server memilih menu yang **benar-benar tersedia** hari ini, lalu aplikasi menampilkannya sebagai kartu menu yang bisa dibuka ke detail atau dimasukkan ke keranjang.
- Batas server: **10 pertanyaan per 10 menit** per akun. Kalau terlewati, aplikasi menampilkan "Coba lagi beberapa menit lagi". Kalau AI di server belum aktif atau gagal, server tetap memberi menu cadangan (ditandai "tanpa AI").

### 💳 C. Bagian Pembayaran & Integrasi Backend (Untuk Rohan, Ammar, & Diego)
- Aplikasi sekarang sudah **tersambung ke backend API** (bukan lagi database lokal). Base URL default-nya server produksi: `https://ketring-45f82aef1ca0.herokuapp.com/api/v1`. Mau pakai server lain (misal backend lokal)? Jalankan dengan `flutter run --dart-define=API_BASE_URL=https://alamat-server-kamu/api/v1`.
- **Login** bisa pakai **email atau nomor WA** + password.
- **Pembayaran hanya lewat Midtrans**: Virtual Account (VA) dan QRIS/e-wallet, dibuka lewat Snap di dalam aplikasi.
- **Sebelum ngetes pembayaran:** cek dulu di Heroku (Settings → Config Vars) bahwa `MIDTRANS_IS_PRODUCTION` **kosong/`false`** (mode sandbox), supaya tidak ada uang sungguhan yang berpindah.
- Mau isi toko demo supaya katalog nggak kosong? Jalankan `dart run tool/seed_toko.dart` (detail lengkap ada di `tool/README.md`).
- **Midtrans sudah terintegrasi.** Alur checkout (buat pesanan) ada di `lib/screens/orders/checkout_screen.dart`, sedangkan halaman pembayaran (VA, QRIS/e-wallet lewat Snap, dan pengecekan status) ada di `lib/screens/orders/payment_screen.dart`.
- **SOP penyambungan ke backend.** Aplikasi mobile ini jadi **acuan**: backend dan web yang menyesuaikan. Peta setiap fitur mobile ke endpoint dan halaman web penjual/admin, aturan penyambungan, dan cara memastikannya ada di [`docs/SOP-PENYAMBUNGAN-MOBILE.md`](https://github.com/stanlevv/kateringkita-backend/blob/main/docs/SOP-PENYAMBUNGAN-MOBILE.md) (repo backend).
- **Tes kontrak** (`test/kontrak/`) menjalankan repository & model aplikasi yang asli ke backend sungguhan: `flutter test test/kontrak --dart-define=KONTRAK_API=http://127.0.0.1:5000/api/v1`. Tes ini membuat akun dan pesanan, jadi **arahkan ke backend lokal, jangan production**. Tanpa `KONTRAK_API` tes ini dilewati.

---

## 🚑 5. P3K: Solusi Cepat Kalau Kena Error di Laptopmu

Kalau waktu mau jalanin tiba-tiba muncul error, jangan panik! Cek solusinya di sini:

### Kasus 1: Muncul error setelah `git pull` atau ganti branch
Kadang setelah `git pull` ada package baru (seperti `webview_flutter` atau `flutter_map`) yang belum ter-registrasi di build lama kamu. Jalankan 3 perintah sakti ini secara berurutan:
```bash
flutter clean
flutter pub get
flutter run
```

### Kasus 2: Error `MissingPluginException` setelah ada plugin baru
**Penyebab:** Kamu cuma tekan *Hot Reload* (`r`) setelah ada penambahan plugin native baru (mis. `webview_flutter` / `flutter_secure_storage`).  
**Solusi:** **Stop** aplikasinya (`q` di terminal atau tombol kotak merah di VS Code), lalu jalankan ulang **`flutter run`** dari awal.

### Kasus 3: Error `Gradle build failed` / `Java version mismatch`
**Penyebab:** Android Studio kamu belum mengarah ke JDK 17+.  
**Solusi:**
1. Cek dokter Flutter dengan ketik:
   ```bash
   flutter doctor -v
   ```
2. Pastikan bagian **Android toolchain** dan **Android Studio** sudah centang hijau `[✓]`.
3. Kalau belum ada Android SDK Command-line Tools, buka **Android Studio → Settings → Languages & Frameworks → Android SDK → Tab SDK Tools**, centang **Android SDK Command-line Tools (latest)** lalu klik **Apply**.
4. Jalankan `flutter doctor --android-licenses` di terminal dan ketik `y` sampai selesai.

---

## 📂 6. Struktur Folder Singkat (Biar Gampang Nyari File)

```text
kateringkita-mobile/
├── android/                  # Konfigurasi Android & Permission (Internet)
├── assets/images/            # Gambar produk, banner promo, & aset UI
├── lib/
│   ├── main.dart             # Titik masuk utama aplikasi (Entry point)
│   ├── api/                  # Klien HTTP ke backend API (ApiClient, config base URL)
│   ├── core/                 # Warna tema, route navigasi, format Rupiah & waktu WIB
│   ├── data/                 # Repo Auth, Katalog, Pesanan, Favorit, Notifikasi, Asisten; Settings & Token Store
│   ├── models/               # Model data Produk, Order, Cart, Notifikasi, & Rekomendasi AI
│   ├── providers/            # State management (Provider)
│   ├── services/             # MapService (konfigurasi tile OpenStreetMap)
│   ├── screens/              # Semua halaman UI:
│   │   ├── ai/               # Halaman AI Assistant (rekomendasi menu dari backend)
│   │   ├── auth/             # Login, Register, Lupa Password, OTP
│   │   ├── home/             # Home, Search, Detail Produk, Notifikasi
│   │   ├── liked/            # Menu Favorit
│   │   ├── navigation/       # Bottom Navigation Bar Utama
│   │   ├── orders/           # Checkout, Pilih Titik Temu, Payment, Active/Completed Orders
│   │   └── profile/          # Profil Pengguna
│   └── widgets/              # Komponen UI reusable (Button, Card, Modal, TextField)
└── pubspec.yaml              # Daftar package & aset aplikasi
```

Selamat ngoding & semangat buat UAS-nya! Kalau ada yang bingung waktu *setup*, langsung kabari di grup ya! 🔥🚀
