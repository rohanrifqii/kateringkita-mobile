# 🍱 KateringKita Mobile (Flutter App)

Halo tim **KateringKita** (Abdurrahim, Rohan, Diego, Ammar)! 👋  
Ini adalah *repository* aplikasi **Mobile KateringKita** (Flutter). Supaya waktu kalian *clone* atau *pull* project ini di laptop masing-masing **nggak kena drama error beda versi, gagal build, atau layar merah**, tolong baca panduan santai di bawah ini secara urut ya!

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

---

## 🚫 3. Apa yang JANGAN Diubah / Disentuh Tanpa Koordinasi!

Supaya kodingan kita nggak bentrok (*conflict*) atau bikin error di laptop teman lain, **tolong jangan ubah file-file ini kecuali memang tugasmu:**

1. ❌ **Jangan hapus atau edit manual `lib/data/app_database.g.dart`**
   - Ini adalah file otomatis (*generated file*) dari database lokal **Drift (SQLite)**. Kalau file ini kamu hapus atau edit manual, seluruh fitur Login, Register, dan Order bakal langsung merah semua!
2. ❌ **Jangan jalanin `flutter pub upgrade --major-versions`**
   - Kita udah ngunci kombinasi versi package yang paling stabil di `pubspec.yaml` dan `pubspec.lock`. Kalau kamu paksa *upgrade major versions*, beberapa package bisa nggak kompatibel satu sama lain. Cukup pakai **`flutter pub get`** aja!
3. ❌ **Jangan utak-atik versi di `android/settings.gradle.kts`, `android/app/build.gradle.kts`, atau `gradle-wrapper.properties`**
   - Versi Java 17, Kotlin 2.4.0, dan Gradle 9.3.1 di sana udah disetel pas dengan Flutter terbaru.
4. ❌ **Jangan commit folder `build/`, `.dart_tool/`, atau file `android/local.properties`**
   - File `local.properties` itu isinya lokasi SDK di laptop masing-masing (beda laptop beda lokasi). File itu udah masuk di `.gitignore` dan bakal dibuat otomatis sama Flutter di laptopmu.

---

## 🧠 4. Info Penting Buat Tim (Diego, Ammar, & Rohan)

Supaya kalian paham cara kerja fitur-fitur yang udah jalan di Mobile saat ini:

### 🗺️ A. Fitur Maps & Lokasi (`lib/services/map_service.dart` & `location_picker_screen.dart`)
- **100% Gratis & Tanpa Kartu Kredit:** Kita **TIDAK** pakai Google Maps berbayar. Kita pakai **`flutter_map` + OpenStreetMap Resmi (`tile.openstreetmap.org`) + Nominatim Geocoding API**.
- Jadi waktu kalian *run* di laptop masing-masing, **Maps langsung jalan otomatis tanpa perlu daftar API Key apapun!**
- **Penting saat Ngetes Lokasi:** Riwayat lokasi disimpan **per akun user**. Jadi kalau kalian bikin akun baru atau baru pertama kali pilih 1 lokasi, daftar *Riwayat Lokasi* memang sengaja **kosong** (baru terisi kalau kalian udah pernah ganti ke lokasi ke-2 dan seterusnya).

### 🤖 B. Fitur AI Assistant (`lib/services/gemini_service.dart` & `ai_assistant_screen.dart`)
- Halaman **AI Assistant** sudah dilengkapi **Hybrid AI Engine**:
  1. **Mode Langsung Jalan (Tanpa Setup Apapun):** Di dalam kodingan sudah ada *Smart Catalog AI Engine* + *Knowledge Base KateringKita*. Jadi waktu Diego/Ammar/Rohan langsung ketik `flutter run`, fitur kalkulasi *Profit Maksimal* (1 menu paling cuan), *Variasi Menu* (5 menu beragam), dan *Chat AI* **sudah langsung berfungsi 100% tanpa kendala!**
  2. **Mode Live Gemini API (Opsional buat Developer):** Kalau mau mengetes pakai API Key Google AI Studio milik sendiri tanpa mengubah kodingan, cukup jalankan:
     ```bash
     flutter run --dart-define=GEMINI_API_KEY=AIzaSy_ISI_API_KEY_KAMU_DISINI
     ```
- AI juga sudah dipasangi **Guardrail Konteks KateringKita**: AI tahu posisinya adalah asisten resmi KateringKita dan bakal menolak dengan sopan kalau ditanya hal-hal di luar katering/danusan.

### 💳 C. Bagian Pembayaran & Integrasi Backend (Untuk Rohan, Ammar, & Diego)
- Saat ini data *User* dan *Orders* disimpan di database lokal HP menggunakan **Drift SQLite (`lib/data/app_database.dart`)** karena tahap sinkronisasi *Web ↔ Backend API ↔ Mobile* baru akan digarap minggu depan.
- Untuk **Rohan (Payment):** Alur checkout ada di `lib/screens/orders/checkout_screen.dart` dan halaman pembayaran ada di `lib/screens/orders/payment_screen.dart`. Kalau mau diintegrasikan ke Midtrans / Payment Gateway, kamu bisa langsung masuk dari kedua file tersebut.

---

## 🚑 5. P3K: Solusi Cepat Kalau Kena Error di Laptopmu

Kalau waktu mau jalanin tiba-tiba muncul error, jangan panik! Cek solusinya di sini:

### Kasus 1: Muncul error setelah `git pull` atau ganti branch
Kadang setelah `git pull` ada package baru (seperti `geolocator` atau `flutter_map`) yang belum ter-registrasi di build lama kamu. Jalankan 3 perintah sakti ini secara berurutan:
```bash
flutter clean
flutter pub get
flutter run
```

### Kasus 2: Error `MissingPluginException` waktu klik tombol GPS / Maps
**Penyebab:** Kamu cuma tekan *Hot Reload* (`r`) setelah ada penambahan plugin native baru (`geolocator` / `flutter_secure_storage`).  
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

### Kasus 4: Tidak sengaja mengubah tabel di `app_database.dart`
Kalau ke depannya kita perlu nambah kolom di tabel SQLite (`lib/data/app_database.dart`), jalankan perintah ini untuk men-generate ulang `app_database.g.dart`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 📂 6. Struktur Folder Singkat (Biar Gampang Nyari File)

```text
kateringkita-mobile/
├── android/                  # Konfigurasi Android & Permission (Internet, GPS)
├── assets/images/            # Gambar produk, banner promo, & aset UI
├── lib/
│   ├── main.dart             # Titik masuk utama aplikasi (Entry point)
│   ├── core/                 # Warna tema, route navigasi, format Rupiah, config AI
│   ├── data/                 # Database SQLite (Drift), Auth Repo, Settings & Token Store
│   ├── models/               # Model data Produk, Order, Cart, & AI Recommendation
│   ├── providers/            # State management (Provider)
│   ├── services/             # GeminiService (AI Assistant) & MapService (OpenStreetMap & GPS)
│   ├── screens/              # Semua halaman UI:
│   │   ├── ai/               # Halaman AI Assistant & Sidebar Riwayat Chat
│   │   ├── auth/             # Login, Register, Lupa Password, OTP
│   │   ├── home/             # Home, Search, Detail Produk, Notifikasi
│   │   ├── liked/            # Menu Favorit
│   │   ├── navigation/       # Bottom Navigation Bar Utama
│   │   ├── orders/           # Checkout, Location Picker (Maps), Payment, Active/Completed Orders
│   │   └── profile/          # Profil Pengguna
│   └── widgets/              # Komponen UI reusable (Button, Card, Modal, TextField)
└── pubspec.yaml              # Daftar package & aset aplikasi
```

Selamat ngoding & semangat buat UAS-nya! Kalau ada yang bingung waktu *setup*, langsung kabari di grup ya! 🔥🚀
