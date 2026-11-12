# Desain — Menyambungkan Mobile KateringKita ke Backend Production

Tanggal: 2026-11-12 · Repo: `kateringkita-mobile` (basis `main` @ `200d2d3`) · Status: draf, menunggu persetujuan

## 1. Maksud dan alasan

Aplikasi mobile (Flutter) saat ini **tidak pernah memanggil backend**. Akun, katalog, favorit, pesanan, pembayaran,
notifikasi, dan profil toko semuanya data dummy atau SQLite lokal. Akibatnya pesanan dari HP tidak pernah sampai ke
penjual, dan akun hanya hidup di satu HP. Backend production (`https://ketring-45f82aef1ca0.herokuapp.com/api/v1`,
repo `stanlevv/kateringkita-backend` @ `main` 2026-11-10) sudah menyediakan semua endpoint pembeli.

Tujuan: semua layar mobile memakai **data asli dari backend production**, tanpa dummy, dengan tampilan yang
dipertahankan. Waktunya mepet, jadi alur pesan didahulukan.

## 2. Tujuan, bukan tujuan, anti-tujuan

**Tujuan**
- Alur pesan nyata: daftar/masuk → lihat menu → keranjang → checkout → bayar Midtrans → pesanan terlihat di dashboard
  penjual → status pesanan di mobile ikut berubah.
- Semua data dummy (`ProductData.mockProducts`, `OrderData.mockOrders`, `VendorData`, `LikedStore.defaultLikedIds`,
  hasil cari hardcoded, notifikasi contoh, sesi contoh AI) dihapus dan diganti API.
- Tidak ada rahasia di aplikasi (API key Gemini dihapus).

**Bukan tujuan**
- Mengubah backend (`be/`). Mobile menyesuaikan kontrak backend yang ada.
- Push notification (FCM), mode offline/cache, desain ulang tampilan.

**Anti-tujuan** (gagal walau "jalan")
- Ada layar yang menampilkan sukses untuk aksi yang tidak terjadi (pura-pura bayar, pura-pura OTP, pura-pura kirim WA).
- Harga/total dihitung di HP lalu dipercaya. Total selalu dari server (`/orders/quote`, `Order.total`).
- Pembayaran memakai uang asli selama pengujian.
- Data dummy baru ditambahkan sebagai "sementara".

## 3. Batasan

- **Backend tetap**; kontrak = kode backend `main` + `docs/API.md` monorepo. Bila keduanya beda, kode backend menang.
- **Pembayaran hanya Midtrans** (tanpa tunai, tanpa QRIS manual). Bila server belum punya kunci Midtrans,
  `POST /orders` dengan `va`/`online` → 409 "Pembayaran … belum tersedia" dan checkout tidak bisa selesai — tampilkan
  pesannya apa adanya.
- **Midtrans harus sandbox** selama pengujian: `MIDTRANS_IS_PRODUCTION` di Heroku harus kosong/`false`
  (bawaan backend = sandbox). Mobile tidak bisa memaksanya; dicek manusia di dashboard Heroku sebelum uji bayar.
- Pengujian ke **production** memakai akun yang diuji sendiri oleh pemilik; data uji akan masuk database asli.
- Tidak ada Flutter SDK di laptop ini saat dokumen ditulis (lihat §8).
- Ketentuan README repo mobile (wajib dipatuhi):
  - Flutter **3.47.x** stable, Dart ^3.13.4, JDK 17, Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0.
  - **Jangan** `flutter pub upgrade --major-versions`; package baru ditambah dengan `flutter pub add` lalu
    `flutter pub get` (lock file ikut di-commit).
  - **Jangan** ubah versi di `android/settings.gradle.kts`, `android/app/build.gradle.kts`,
    `gradle-wrapper.properties`.
  - **Jangan** commit `build/`, `.dart_tool/`, `android/local.properties`.
  - Jangan edit manual `app_database.g.dart` — di desain ini Drift dibuang utuh (file `.dart` + `.g.dart` + dependency),
    tidak diedit sebagian.
  - README bagian 4 (Maps, AI, Pembayaran & Drift) dan bagian 5 Kasus 4 (build_runner) **diperbarui** di branch yang
    mengubah hal tersebut, supaya tim tidak mengikuti petunjuk yang sudah tidak berlaku.
  - Maps memakai `flutter_map` + OSM (tanpa API key) — tetap dipakai untuk peta latar.
- Teks UI bahasa Indonesia tanpa istilah teknis. Harga = integer Rupiah dari server.

## 4. Pendekatan yang dipertimbangkan

| Pendekatan | Untung | Rugi |
|---|---|---|
| **A. `http` + Provider (dipilih)** | `http` & `provider` sudah ada; pola sudah dikenal tim; tanpa build step; paling ringan | timeout/retry ditulis sendiri (beberapa baris) |
| B. `dio` + interceptor | interceptor rapi | dependency & pola baru, manfaat kecil untuk app ini |
| C. `retrofit` + `json_serializable` | model otomatis | butuh `build_runner` tiap ubah, boilerplate, paling lambat saat mepet |

Pemilik memilih **A** ("paling simpel dan performa").

## 5. Keputusan pemilik (dari diskusi)

1. Tampilan mobile dipertahankan; data & aturan ikut backend.
2. Kerja di `C:\PROJECT\kateringkita-mobile` (basis `main` terbaru). `mobile/` di monorepo identik dengan commit
   `3a27790` (tidak ada kerja unik), jadi setelah selesai `mobile/` monorepo **disamakan** dengan hasil akhir.
3. Base URL: production Heroku.
4. Lokasi: **peta tetap + titik temu** — peta (flutter_map/OSM yang sudah ada) sebagai latar area kampus, pilihan
   berupa daftar titik temu dari API di bawah peta. Backend tidak punya koordinat titik temu → tanpa pin per titik.
5. Bayar: **semua lewat Midtrans**, tunai dihapus dari pilihan, QRIS manual dihapus.
6. Snap Midtrans dibuka di **WebView dalam app** (`webview_flutter`).
7. Keranjang multi-menu, **satu toko** per keranjang.
8. **Boleh jelajah sebagai tamu**; login diminta saat favorit, checkout, pesanan, profil, notifikasi, AI.
9. SQLite lokal (Drift: tabel `users`, `orders`) **dibuang**; semua dari server.
10. Midtrans sandbox; pemilik menguji sendiri dengan akunnya.
11. AI Assistant lewat `POST /assistant/recommendations`; Gemini & API key dihapus dari app.
12. Notifikasi: diambil dari server berkala (tanpa FCM).
13. Git: **satu branch per fitur**, commit author `stanlevv <256969117+stanlevv@users.noreply.github.com>`,
    di-push dengan login GitHub `stanlevv`, **tidak di-push sebelum pemilik bilang**.
14. Waktu mepet: alur pesan dulu.

## 6. Rancangan

### 6.1 Fondasi (`lib/api/`)
- `ApiConfig.baseUrl` = `String.fromEnvironment('API_BASE_URL', defaultValue: <production>)`. Production URL boleh
  jadi bawaan untuk app ini karena memang target pemilik (catatan: aturan monorepo "jangan ada URL production di kode"
  berlaku untuk `be/`/`fe/`; di sini URL publik API, bukan rahasia).
- `ApiClient` (satu instance, dibagikan lewat Provider): `get/post/put/patch/delete`, timeout 15 dtk, header
  `Authorization: Bearer` dari `TokenStore`, `Accept: application/json`. Membuka amplop `{ data, meta }`.
  Galat backend `{ error: { code, message, fields? } }` → `ApiException(status, code, message, fields)`;
  401 pada request ber-token → hapus token & arahkan ke login. Tanpa jaringan → pesan "Tidak ada koneksi internet."
- `TokenStore`: hanya JWT + `expires_at` di secure storage. Fungsi simpan password dihapus.
- Izin `INTERNET` di `android/app/src/main/AndroidManifest.xml`.
- Model diparse manual (`fromJson`), mengikuti objek `MenuCard`, `Order`, dll. di API.md §1.
- `Idempotency-Key`: UUID v4 dibuat dengan `Random.secure()` (tanpa package `uuid`), satu per niat checkout,
  dipakai ulang saat coba lagi.

### 6.2 Repository + state
Satu repository per domain di `lib/data/` (memanggil `ApiClient`), `ChangeNotifier` hanya bila dibagi antar layar:
`AuthProvider` (user sesi), `CartProvider` (keranjang), `FavoriteProvider` (set id favorit),
`NotificationProvider` (jumlah belum dibaca). Layar lain memanggil repository langsung + `FutureBuilder`/state lokal.

### 6.3 Pemetaan layar → endpoint

| Layar | Endpoint | Dummy yang dibuang |
|---|---|---|
| Splash | `GET /me` bila ada token; gagal 401 → tamu | sesi `dev-token` |
| Login | `POST /auth/login { identifier, password, client:"mobile" }` (email **atau** no WA) | auth SQLite |
| Daftar | `POST /auth/customer/register` lalu login | tabel `users` |
| Lupa password / OTP / reset | `/auth/password/forgot` → `/verify` → `/reset` | OTP apa pun diterima |
| Home | `/meta/categories`, `/menus?category=&sort=`, `/me/notifications?unread=true` (bila login) | `mockProducts`, kategori lokal |
| Banner promo | **tidak ada endpoint** → gambar banner dibiarkan (§6.5c); tap tidak lagi ke produk dummy, melainkan ke Cari | rujukan `mockProducts[i]` |
| Cari | `/menus?q=&category=&sort=` | hasil hardcoded |
| Detail menu | `/menus/:id`, `/menus/:id/reviews` | opsi/badge statis |
| Profil toko | `/merchants/:slug` + `/menus?merchant=slug`; field yang tak ada di API (jarak, halal, prime, promo toko) disembunyikan | `VendorData` |
| Keranjang/Checkout | `/orders/quote` (ulang tiap ubah qty/opsi/titik temu/promo), `POST /orders` | total lokal, kode order lokal |
| Lokasi | titik temu dari `merchant.pickup_points` di `/menus/:id`; bawaan = `favorite_pickup_point_id` bila dilayani | GPS bebas |
| Bayar VA | `POST /orders` `payment_method:"va"` → `POST /orders/:code/va { bank }` → tampil nomor VA + batas waktu | VA palsu |
| Bayar QRIS/e-wallet | `payment_method:"online"` → `POST /orders/:code/online` → `redirect_url` di WebView | QR painter palsu |
| Status bayar | `GET /orders/:code` saat WebView ditutup + tiap 5 dtk di layar bayar sampai `paid`/batal/kedaluwarsa | jeda 1,2 dtk "lunas" |
| Pesanan Aktif/Selesai/Batal | `/me/orders?tab=`, refresh saat dibuka/tarik + tiap 15 dtk; tombol dari `can_cancel/can_complete/can_review` | `mockOrders`, Drift |
| Batal / Selesai | `POST /orders/:code/cancel`, `/complete` | ubah status lokal |
| Kirim WA | `GET /orders/:code/whatsapp` → buka `url` via `url_launcher` | pesan disusun di HP |
| Pesan lagi | `POST /orders/:code/reorder` → isi keranjang → quote | — |
| Ulasan | `POST /orders/:code/reviews` per menu | — |
| Favorit | `GET /me/favorites`, `PUT/DELETE /me/favorites/:menuId` | `LikedStore` |
| Profil / Edit | `GET/PATCH /me`, `POST /me/avatar` → PUT ke `upload_url` → `PATCH /me {avatar_url}`, `PUT /me/password`, `POST /auth/logout` | profil SQLite/prefs |
| Notifikasi | `GET /me/notifications`, `POST /me/notifications/read`; tiap 30 dtk saat app di depan | notifikasi contoh |
| AI Assistant | `POST /assistant/recommendations` | Gemini langsung, sesi contoh |

### 6.4 Pembayaran Midtrans (rinci)
- Pilihan metode di checkout: **Virtual Account** (pilih bank BCA/BNI/BRI) dan **QRIS / e-wallet** (Snap).
- Alur: quote → `POST /orders` (status `holding`) → layar bayar.
  - VA: panggil `/va` sekali, tampilkan nomor VA, bank, nominal, `hold_until`; tombol salin; poll status.
  - Online: panggil `/online` (body kosong), buka `redirect_url` di WebView; saat user menutup WebView atau URL
    pindah ke halaman selesai, cek `GET /orders/:code`.
- Selesai bila `payment.status = paid` → layar sukses → daftar pesanan. Bila `hold_until` lewat → pesan kedaluwarsa.
- Tidak ada layar "berhasil" tanpa konfirmasi server.

### 6.5 Tamu & sesi
- Tanpa token: Home/Cari/Detail/Profil toko bisa dibuka; aksi yang butuh akun membuka Login lalu kembali.
- Setelah login sukses, keranjang tetap.

### 6.5a Keranjang (keputusan pemilik)
Checkout **menjadi** keranjang: tombol di detail menu = "Tambah ke keranjang" (tetap di halaman, snackbar);
ikon keranjang + jumlah di Home dan detail membuka layar checkout yang kini berisi **daftar menu** (qty, opsi, hapus).
Menu dari toko lain → dialog "Kosongkan keranjang dan ganti toko?". Keranjang disimpan di memori (`CartProvider`).

### 6.5b Waktu ambil & pre-order (keputusan pemilik)
- Checkout punya pemilih waktu ambil: **"Secepatnya"** (`pickup_at: null`) atau tanggal + jam WIB (maks 7 hari).
- Bila keranjang berisi menu pre-order: "Secepatnya" dinonaktifkan; pembeli **wajib** memilih tanggal ≥ H-`preorder_days`
  (awal hari WIB). Pre-order **bayar penuh** — otomatis terpenuhi karena semua pembayaran Midtrans penuh.
- `pickup_at` dikirim ISO-8601 dengan zona `+07:00`.

### 6.5c UI tanpa data backend (keputusan pemilik: **biarkan apa adanya**)
Bagian yang tidak punya endpoint dibiarkan seperti sekarang (perilaku lokal): AI hitung modal/profit/ROI & riwayat chat,
edit profil gender/tanggal lahir/bio, PIN/biometrik, toggle notifikasi, bahasa, "Beri Rating" aplikasi, tab notifikasi
Promo/Info, banner. Hanya bagian yang **punya** endpoint yang diganti data asli. Pengecualian yang tetap harus ikut
backend karena menyimpan ke server: ubah email/no HP di `PATCH /me` wajib `current_password` — layar edit profil
meminta kata sandi saat email/HP berubah (langkah OTP 4 digit yang ada dibiarkan). *(Catatan: ini mengubah keputusan
"banner disembunyikan" di §6.3 — banner dibiarkan apa adanya.)*

### 6.6 Yang dihapus
`lib/data/app_database.dart(+.g.dart)`, dependency `drift`/`drift_flutter`/`drift_dev`/`build_runner`,
`google_generative_ai`, `lib/core/gemini_config.dart`, `lib/services/gemini_service.dart`, `LikedStore`, semua
`mock*`/`VendorData`, penyimpanan password. `geolocator` dihapus bila tidak dipakai lagi peta latar.

### 6.7 Data toko production (keputusan pemilik: "toko dari mobile jadikan production")
Production belum punya menu tampil (`GET /menus` total 0, dicek 2026-11-12). 5 toko + menu dummy di
`lib/models/vendor_model.dart` (Diego Katering, Martabak Pecenongan, Dapur Slamet, Surgawi Bakery, Dapur Bu Tima)
dijadikan **data asli** di production lewat API resmi (bukan SQL langsung), dengan skrip sekali jalan di luar `lib/`
(mis. `tool/seed_toko.dart`, tidak masuk app):
1. `POST /auth/merchant/register` per toko (jenis usaha, alamat, jam buka dari data mobile).
2. Admin memverifikasi lewat `POST /admin/merchants/:id/verify` (pakai akun admin pemilik, dimasukkan saat jalan,
   tidak disimpan).
3. Login penjual → `PATCH /merchant/profile` (jam buka, titik temu, `wa_number`) → `PATCH /merchant/status {is_open}`.
4. `POST /merchant/menus` per menu (harga, kategori dipetakan ke slug backend, kuota harian, deskripsi, opsi).
5. Foto: `POST /merchant/uploads` → PUT gambar dari `assets/images/` ke R2 → `image_url`.
Skrip idempoten (lewati toko/menu yang sudah ada). Dijalankan **hanya** atas perintah pemilik.

Keputusan pemilik untuk seed:
- **Nomor WA** tetap nomor karangan dari data mobile (`6281234567890` dst., dinormalkan ke `08…`). Risiko diterima
  pemilik: pesan WA pembeli bisa sampai ke pemilik nomor yang sebenarnya.
- **Foto**: R2 di Heroku **diperbaiki dulu oleh pemilik** (R2_ACCOUNT_ID & R2_ACCESS_KEY_ID), baru skrip mengunggah
  gambar dari `assets/images/`. Seed menunggu R2 beres.
- **Akun**: login admin dan email/no HP/password 5 penjual diketik pemilik saat skrip jalan (input interaktif lewat
  `! <perintah>`), tidak disimpan di berkas atau repo.

## 7. Urutan branch (bertumpuk, satu fitur satu branch)

Setiap branch dibuat dari branch sebelumnya (karena saling bergantung), commit per langkah, author `stanlevv`:

0. `chore/seed-toko-production` — skrip `tool/seed_toko.dart` (§6.7); bisa dikerjakan paralel, dijalankan setelah R2 beres
1. `feat/api-fondasi` — ApiClient, TokenStore, izin INTERNET, model dasar
2. `feat/auth` — splash, login, daftar, logout, lupa password OTP, mode tamu
3. `feat/katalog` — home, kategori, cari, detail, ulasan menu, profil toko
4. `feat/keranjang-checkout` — keranjang satu toko, quote, titik temu + peta latar, buat pesanan
5. `feat/bayar-midtrans` — VA, Snap WebView, poll status
6. `feat/pesanan` — tab pesanan, batal, selesai, WA, pesan lagi, ulasan
7. `feat/favorit`
8. `feat/profil` — profil, edit, avatar, ganti password, titik temu favorit
9. `feat/notifikasi`
10. `feat/ai-backend`
11. `chore/hapus-dummy` — buang Drift, Gemini, sisa mock (bisa digabung ke branch terakhir yang menyentuhnya)

Setelah semua disetujui: samakan `mobile/` di monorepo dengan hasil akhir; push hanya atas perintah pemilik.

## 8. Diserahkan ke pembangun / masih terbuka

- **Verifikasi** *(keputusan Claude)*: Flutter **3.47.9** dipasang di `C:\src\flutter` (sesuai README 3.47.x; clone
  `stable` ternyata 3.50 candidate, jadi diganti). Tiap branch wajib lulus `flutter analyze` + `flutter test`
  (unit test untuk `ApiClient`, parsing model, `CartProvider`). `build apk` menunggu Android SDK + JDK 17.
- **Sinkron `mobile/` monorepo** *(keputusan Claude)*: di akhir hanya **menyalin berkas** hasil akhir ke
  `Kteringkita/mobile/`, **tanpa commit** di monorepo (working tree monorepo berisi perubahan `fe/` milik orang lain);
  commit monorepo diputuskan pemilik.
- Bentuk persis respons tiap endpoint dibaca dari kode backend `main` saat menulis model (bukan dari ingatan).
- Tata letak detail elemen yang disembunyikan (banner, jarak toko) — pembangun merapikan agar tidak ada ruang kosong.
- Interval polling (5/15/30 dtk) boleh disesuaikan bila terasa berat.
