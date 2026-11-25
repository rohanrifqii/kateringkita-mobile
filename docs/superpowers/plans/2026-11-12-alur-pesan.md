# Alur Pesan (Mobile ↔ Backend) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pembeli bisa daftar/masuk, melihat menu asli, mengisi keranjang, checkout, bayar lewat Midtrans (sandbox), dan memantau pesanannya — semuanya dari backend production, tanpa data dummy di jalur ini.

**Architecture:** Satu `ApiClient` tipis di atas `package:http` (amplop `{data,meta}` / `{error}`), repository per domain di `lib/data/`, `ChangeNotifier` hanya untuk state lintas layar (`AuthProvider`, `CartProvider`). Model diparse manual. Tampilan layar dipertahankan; hanya sumber data dan aksi yang diganti.

**Tech Stack:** Flutter 3.47.9 / Dart 3.13.7 (`C:\src\flutter\bin`), `http` (sudah ada), `provider`, `flutter_secure_storage`, `url_launcher`, `flutter_map`; baru: `webview_flutter`. Test: `flutter_test` + `package:http/testing.dart` `MockClient`.

**Spec:** `docs/superpowers/specs/2026-11-12-sambung-api-design.md`. Kontrak backend: kode `stanlevv/kateringkita-backend@main` (referensi ringkas di bagian "Kontrak" di bawah — **kode backend menang atas `docs/API.md`**).

## Global Constraints

- Flutter **3.47.x**; jangan `flutter pub upgrade --major-versions`; paket baru hanya via `flutter pub add <nama>`; `pubspec.lock` di-commit.
- Jangan ubah versi di `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `gradle-wrapper.properties`.
- Jangan commit `build/`, `.dart_tool/`, `android/local.properties`; kembalikan perubahan otomatis `linux/`/`macos/` plugin registrant (`git checkout -- linux macos`) bila tidak relevan.
- Base URL: `String.fromEnvironment('API_BASE_URL', defaultValue: 'https://ketring-45f82aef1ca0.herokuapp.com/api/v1')`.
- Uang = `int` Rupiah dari server; total **tidak pernah** dihitung di HP untuk dikirim/dipercaya.
- Teks UI Bahasa Indonesia tanpa istilah teknis. Pesan galat server (`error.message`) ditampilkan apa adanya.
- Tidak ada layar sukses tanpa konfirmasi server. Tidak menambah data dummy baru.
- Bagian UI tanpa endpoint dibiarkan apa adanya (spec §6.5c).
- Pembayaran hanya `va` dan `online` (Midtrans); opsi tunai **tidak** ditampilkan.
- Setiap task selesai dengan `flutter analyze` bersih dan `flutter test` hijau (dijalankan dengan `export PATH="/c/src/flutter/bin:$PATH"`).
- Commit: `git -c user.name=stanlevv -c user.email=256969117+stanlevv@users.noreply.github.com commit -m "<pesan>"` dengan trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. **Tidak ada push.**
- Repo: `C:\PROJECT\kateringkita-mobile`. Tiap gelombang paralel dikerjakan di git worktree terpisah (`superpowers:using-git-worktrees`).

## Branch & gelombang

| Gelombang | Branch (basis) | Task |
|---|---|---|
| 1 | `feat/api-fondasi` (dari `main`, sudah ada, berisi commit spec) | 1, 2 |
| 2 (paralel) | `feat/auth` (dari fondasi) | 3, 4 |
| 2 (paralel) | `feat/katalog` (dari fondasi) | 5, 6, 7 |
| 2 (paralel) | `chore/seed-toko-production` (dari fondasi) | 8 |
| 3 | `feat/keranjang-checkout` (dari merge `feat/auth` + `feat/katalog`) | 9, 10 |
| 4 (paralel) | `feat/bayar-midtrans` (dari checkout) | 11, 12 |
| 4 (paralel) | `feat/pesanan` (dari checkout) | 13, 14 |
| Akhir | `integrasi/alur-pesan` (merge semua) | 15 |

## Review Focus

1. **Jaringan putus saat `POST /orders`** → coba lagi memakai `Idempotency-Key` yang sama; tidak boleh lahir dua pesanan. (Task 10)
2. **Token kedaluwarsa/dicabut (401 di rute ber-auth)** → token dihapus, pengguna dibawa ke Login, tidak ada spinner abadi. (Task 1, 3)
3. **Toko tutup / di luar jam buka** → detail menu menampilkan "Toko sedang tutup", tombol tambah nonaktif; checkout menampilkan pesan `MERCHANT_CLOSED` dari server. (Task 7, 10)
4. **Masa tahan habis saat membayar** (VA/Snap) → layar bayar berhenti polling dan menampilkan "Batas waktu pesanan sudah habis", bukan sukses. (Task 11)
5. **Katalog kosong** (production saat ini 0 menu) → Home/Cari menampilkan keadaan kosong yang wajar, tidak crash/indeks di luar batas. (Task 6)

---

## Kontrak (ringkas, dari kode backend)

- Sukses `{"data": …, "meta"?: {page,limit,total}}`; galat `{"error":{"code","message","fields"?: {key: [String]}}}` (kunci `fields` bisa tidak ada; kunci bertitik, mis. `items.0.qty`).
- 401 `UNAUTHENTICATED` hanya dari rute wajib-login. `/menus`, `/menus/:id` tidak pernah 401 (token rusak = tamu).
- `POST /auth/login {identifier, password, client:"mobile"}` → `{token, expires_at, user}`. `User` = `{id, role, full_name, email?, phone, avatar_url?, favorite_pickup_point_id?}`.
- `POST /auth/customer/register {full_name,email,phone,password}` → 201 `{user}` (tanpa token → lanjut login). Duplikat → 409 "Data sudah terdaftar.".
- `GET /me` → `{user, merchant}`. `POST /auth/logout` → 204.
- Lupa sandi: `POST /auth/password/forgot {email}` → 200 `{message}`; `/verify {email, code}` → `{valid:true}`; `/reset {email, code, password}` → `{ok:true}`.
- `GET /meta/categories` → `[{id,name,slug,icon}]`; `GET /meta/pickup-points` → `[{id,name,description?}]`.
- `MenuCard` = `{id, name, image_url?, price, unit_label, category{id,name,slug}, merchant{id,slug,business_name,is_open}, available, badge: sold_out|preorder|low_stock|available, rating_avg(double), rating_count, is_favorite}`.
- `GET /menus?q&category&merchant&sort&page&limit` → `{data:[MenuCard], meta}`; tanpa `merchant=` hanya toko yang buka sekarang.
- `GET /menus/:id` → MenuCard + `description?, options[{id,name,extra_price}], min_order_qty, prep_minutes, is_preorder, preorder_days`, `merchant` + `{logo_url?, open_time "HH:MM", close_time, pickup_points[{id,name,description?}]}`.
- `GET /menus/:id/reviews` → `{data:[{rating, comment?, customer_name, created_at}], meta}`.
- `GET /merchants/:slug` → `{id, slug, business_name, description?, logo_url?, merchant_type{id,name}, is_open, open_time, close_time, rating_avg, rating_count, pickup_points[]}`.
- `POST /orders/quote` body `{items[{menu_id,qty,option_ids}], pickup_point_id, note?, promo_code?, customer_name?, customer_phone?, pickup_at?}` → `{items[{menu_id,menu_name,qty,unit_price,options,line_total,available}], subtotal, discount, service_fee, total, warnings[{code,menu_id,available,message}]}`.
- `POST /orders` = quote body + `payment_method: "va"|"online"`, header `Idempotency-Key: <uuid v4>` → 201 `Order + payment`. Galat penting: 409 `CONFLICT` (3 pesanan menunggu), 409 `MERCHANT_CLOSED`, 409 `MERCHANT_UNAVAILABLE`, 409 `OUT_OF_STOCK` (`fields["items.N.qty"]`), 400 `pickup_at` "Menu pre-order harus diambil paling cepat H-{po}.", 409 "Pembayaran … belum tersedia".
- `pickup_at`: kirim `dt.toUtc().toIso8601String()` (harus ber-zona). Pre-order: wajib, ≥ 00:00 WIB hari (hari ini WIB + `po`), `po` = `preorder_days` terbesar di keranjang; maks 7 hari ke depan; toko tetap harus buka saat checkout.
- `Order` = `{code, status: holding|confirmed|cooking|ready|completed|cancelled|expired, payment_method, payment_status: unpaid|pending|paid|failed|refunded, hold_until?, seconds_left?, pickup_point{id,name}, items[{menu_id,menu_name,qty,unit_price,options,line_total}], subtotal, discount, service_fee, total, note?, pickup_at?, cancel_reason?, cancelled_by?, created_at, updated_at, merchant{id,business_name,wa_number}, can_cancel, can_complete, can_review}`; `GET /orders/:code` menambah `payment{method,status,amount, va?:{bank,va_number,expires_at}, payment_url?}`.
- `POST /orders/:code/va {bank: bca|bni|bri}` → Order+payment (idempoten). `POST /orders/:code/online` (tanpa body) → Order+payment dengan `payment.payment_url` (Snap). Lunas hanya lewat webhook `settlement` → status `confirmed`, `payment_status: paid`.
- `GET /me/orders?tab=active|completed|cancelled&q&page&limit` → `{data:[Order], meta}` (tanpa `payment`).
- `POST /orders/:code/cancel {reason?}`, `/complete` → Order+payment. `GET /orders/:code/whatsapp` → `{wa_number, message, url}`. `POST /orders/:code/reorder` → `{request, quote}`. `POST /orders/:code/reviews {items[{menu_id, rating 1–5, comment?}]}` → 201 `{order_code, reviewed_menu_ids}`.

---

## Gelombang 1 — `feat/api-fondasi`

### Task 1: ApiClient, TokenStore, izin INTERNET

**Files:**
- Create: `lib/api/api_config.dart`, `lib/api/api_client.dart`, `lib/api/api_exception.dart`, `lib/api/idempotency.dart`
- Modify: `lib/data/token_store.dart` (hapus `savePassword`/`readPassword`), `android/app/src/main/AndroidManifest.xml` (tambah `<uses-permission android:name="android.permission.INTERNET"/>`)
- Test: `test/api/api_client_test.dart`, `test/api/idempotency_test.dart`

**Interfaces:**
- Produces:
  - `class ApiConfig { static const String baseUrl; }`
  - `class ApiException implements Exception { final int status; final String code; final String message; final Map<String, List<String>> fields; String? field(String key); }` — `field` mengembalikan pesan pertama atau null.
  - `class ApiResponse { final dynamic data; final Map<String, dynamic>? meta; final int status; }`
  - `class ApiClient { ApiClient({http.Client? client, String? baseUrl, Future<String?> Function()? readToken, Future<void> Function()? onUnauthorized}); Future<ApiResponse> get(String path, {Map<String, String>? query}); Future<ApiResponse> post(String path, {Object? body, Map<String, String>? headers}); Future<ApiResponse> put(String path, {Object? body}); Future<ApiResponse> patch(String path, {Object? body}); Future<ApiResponse> delete(String path); }`
  - `String newIdempotencyKey()` — UUID v4 huruf kecil dari `Random.secure()`.
  - `TokenStore`: `saveSession(String token, String email)`, `readToken()`, `readSessionEmail()`, `logout()` (signature lama dipertahankan).

- [ ] **Step 1: Tulis test gagal** di `test/api/api_client_test.dart` memakai `MockClient`:
  - `get('/menus')` dengan respons `{"data":[1],"meta":{"page":1,"limit":20,"total":1}}` → `res.data == [1]`, `res.meta!['total'] == 1`.
  - header `Authorization` = `Bearer abc` bila `readToken` mengembalikan `'abc'`; tidak ada header bila null.
  - respons 400 `{"error":{"code":"VALIDATION_ERROR","message":"Data tidak valid.","fields":{"phone":["Nomor HP harus diawali 08 dan 10–13 digit."]}}}` → melempar `ApiException` dengan `status 400`, `code 'VALIDATION_ERROR'`, `field('phone') == 'Nomor HP harus diawali 08 dan 10–13 digit.'`.
  - respons 409 tanpa `fields` → `fields` kosong (bukan null).
  - respons 401 → `onUnauthorized` dipanggil sekali, lalu melempar `ApiException(status: 401)`.
  - respons 204 → `res.data == null` tanpa error.
  - client melempar `SocketException` → `ApiException(status: 0, code: 'NETWORK', message: 'Tidak ada koneksi internet.')`.
  - timeout (`MockClient` yang menunda > batas; buat batas waktu bisa diatur lewat parameter konstruktor opsional `Duration timeout`, bawaan 15 dtk) → `ApiException(status: 0, code: 'TIMEOUT', message: 'Koneksi lambat. Coba lagi.')`.
  - `post` mengirim `Content-Type: application/json` dan body ter-encode JSON; header tambahan (mis. `Idempotency-Key`) diteruskan.
  - Test `idempotency_test.dart`: `newIdempotencyKey()` cocok `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` dan dua panggilan berbeda.
- [ ] **Step 2: Jalankan** `flutter test test/api` → FAIL (file belum ada).
- [ ] **Step 3: Implementasi** sesuai Interfaces. Respons non-JSON/500 tanpa amplop → `ApiException(status, 'INTERNAL_ERROR', 'Terjadi kesalahan. Coba lagi.')`.
- [ ] **Step 4: Jalankan** `flutter test test/api` → PASS; `flutter analyze` → "No issues found!".
- [ ] **Step 5: Commit** `feat(api): ApiClient, TokenStore tanpa password, izin INTERNET`.

### Task 2: Model data dari kontrak

**Files:**
- Create: `lib/models/api_user.dart`, `lib/models/category_model.dart`, `lib/models/pickup_point.dart`, `lib/models/order_api_model.dart` (Order, OrderItem, OrderPayment, Quote, QuoteWarning)
- Modify: `lib/models/product_model.dart` (ganti isi menjadi model MenuCard/detail; **hapus** `ProductData` belakangan di Task 6), `lib/core/app_currency.dart` (hapus kali-1000 untuk nilai < 500)
- Test: `test/models/product_model_test.dart`, `test/models/order_api_model_test.dart`, `test/models/api_user_test.dart`, `test/core/app_currency_test.dart`

**Interfaces:**
- Produces:
  - `class ApiUser { final int id; final String role; final String fullName; final String? email; final String phone; final String? avatarUrl; final int? favoritePickupPointId; factory ApiUser.fromJson(Map<String, dynamic>); }`
  - `class CategoryModel { int id; String name; String slug; String icon; fromJson }`, `class PickupPoint { int id; String name; String? description; fromJson }`
  - `class MenuOption { int id; String name; int extraPrice; fromJson }`
  - `class MerchantRef { int id; String slug; String businessName; bool isOpen; String? logoUrl; String? openTime; String? closeTime; List<PickupPoint> pickupPoints; fromJson }`
  - `class ProductModel` (nama dipertahankan agar layar tetap kompil): `final int id; String name; int price; String unitLabel; String? imageUrl; CategoryModel? category; MerchantRef merchant; int available; String badge; double ratingAvg; int ratingCount; bool isFavorite; String? description; List<MenuOption> options; int minOrderQty; int prepMinutes; bool isPreorder; int preorderDays; factory ProductModel.fromJson(Map<String, dynamic>)` + getter kompatibilitas: `double get rating => ratingAvg; int get reviewCount => ratingCount; String get vendor => merchant.businessName; bool get isLiked => isFavorite; String? get badgeText; String get badgeType; bool get canOrder => merchant.isOpen && badge != 'sold_out';` + `copyWith({bool? isFavorite})`.
    - `badgeText`: `sold_out` → `'Habis'`, `preorder` → `'Pre-order H-$preorderDays'` (detail) / `'Pre-order'` (kartu, bila `preorderDays == 0`), `low_stock` → `'🔥 Sisa $available Porsi'`, `available` → `'Tersedia'`. `badgeType`: `low_stock`/`sold_out` → `'quota'`, lainnya `'available'`.
  - `class OrderItem { int menuId; String menuName; int qty; int unitPrice; List<MenuOption> options; int lineTotal; }`, `class OrderVa { String bank; String vaNumber; DateTime expiresAt; }`, `class OrderPayment { String method; String status; int amount; OrderVa? va; String? paymentUrl; }`
  - `class OrderApiModel { String code; String status; String paymentMethod; String paymentStatus; DateTime? holdUntil; int? secondsLeft; PickupPoint pickupPoint; List<OrderItem> items; int subtotal; int discount; int serviceFee; int total; String? note; DateTime? pickupAt; String? cancelReason; String? cancelledBy; DateTime createdAt; DateTime updatedAt; int merchantId; String merchantName; String merchantWa; bool canCancel; bool canComplete; bool canReview; OrderPayment? payment; factory fromJson; bool get isPaid => paymentStatus == 'paid'; }`
  - `class QuoteWarning { String code; int menuId; int available; String message; }`, `class Quote { List<OrderItem> items; int subtotal; int discount; int serviceFee; int total; List<QuoteWarning> warnings; fromJson }`
  - `AppCurrency.format(num)` → `'Rp 25.000'`, `0` → `'Rp 0'`, `450` → `'Rp 450'`.

- [ ] **Step 1: Tulis test gagal** — tiap model diparse dari contoh JSON di bagian Kontrak (pakai nilai persis), termasuk: `rating_avg` datang sebagai `4` (int) → `4.0`; `image_url: null`; `options` tidak ada di MenuCard → `[]`; `merchant.pickup_points` tidak ada → `[]`; Order dengan `hold_until: null`, `payment` tidak ada → `payment == null`; Order dengan `payment.va` dan `payment.payment_url`; `badgeText` untuk keempat badge; `AppCurrency.format(450) == 'Rp 450'`, `format(25000) == 'Rp 25.000'`.
- [ ] **Step 2:** `flutter test test/models test/core` → FAIL.
- [ ] **Step 3: Implementasi.** `ProductModel` lama (field String id, `image` aset, `ProductData`) diganti; **biarkan** `ProductData` sementara sebagai shim kosong: `static final List<ProductModel> mockProducts = []` dan `static ProductModel? getProductByName(String name) => null` (`defaultProduct` dihapus) supaya layar yang belum dipindah (favorit, AI, pesanan lama) tetap kompil; shim dihapus di rencana kedua setelah pemakai terakhirnya hilang. Layar yang dulu jatuh ke `defaultProduct` saat argumen kosong (detail, checkout, bayar) kini `Navigator.pop` bila argumen null. Perbaiki semua error kompilasi akibat perubahan tipe (`id` int, `price` int, `image` → `imageUrl`) dengan perubahan minimal: gambar produk di semua layar diganti `MenuImage` (lihat Step 3b).
- [ ] **Step 3b:** Buat `lib/widgets/menu_image.dart`: `class MenuImage extends StatelessWidget { const MenuImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.borderRadius}); }` — `url == null` → `Image.asset('assets/images/logo.png')` di kotak abu-abu; selain itu `Image.network` dengan `errorBuilder` ke gambar pengganti yang sama dan `loadingBuilder` kotak abu-abu. Ganti setiap `Image.asset(<product>.image)` dengan `MenuImage(<product>.imageUrl, …)`. Gambar non-produk (banner, logo, avatar statis) tidak diubah.
- [ ] **Step 4:** `flutter analyze` bersih; `flutter test test/models test/core test/api` → PASS.
- [ ] **Step 5: Commit** `feat(models): model MenuCard, Order, Quote, User dari kontrak backend`.

---

## Gelombang 2a — `feat/auth`

### Task 3: AuthRepository ke backend, AuthProvider, splash/login/daftar, mode tamu

**Files:**
- Modify: `lib/data/auth_repository.dart` (tulis ulang), `lib/main.dart`, `lib/screens/splash/splash_screen.dart`, `lib/screens/auth/login_screen.dart`, `lib/screens/auth/signup_screen.dart`, `test/widget_test.dart`
- Create: `lib/providers/auth_provider.dart`, `lib/core/require_login.dart`
- Modify (kompilasi, perubahan minimal): pemanggil `currentUser()` — `checkout_screen.dart`, `location_picker_screen.dart`, `profile_screen.dart`, `edit_profile_screen.dart`, `ai_assistant_screen.dart` (pakai `ApiUser.fullName/email/phone`).
- Test: `test/data/auth_repository_test.dart`, `test/providers/auth_provider_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `TokenStore`, `ApiUser` (Task 1–2).
- Produces:
  - `class AuthRepository { AuthRepository(ApiClient api); Future<ApiUser> login({required String identifier, required String password}); Future<void> register({required String fullName, required String email, required String phone, required String password}); Future<ApiUser?> currentUser(); Future<void> logout(); Future<String> forgotPassword(String email); Future<void> verifyCode({required String email, required String code}); Future<void> resetPassword({required String email, required String code, required String password}); Future<ApiUser> updateProfile(...)` — `updateProfile`/`changePassword` lama dipertahankan signature-nya tetapi memanggil `PATCH /me` / `PUT /me/password` (dipakai layar profil; detail di rencana kedua, cukup kompil dan memanggil endpoint).
  - `login` mengirim `client: "mobile"`, menyimpan `TokenStore.saveSession(token, user.email ?? identifier)`.
  - `currentUser()` → null bila tidak ada token; `GET /me` → `ApiUser`; 401 → `TokenStore.logout()` lalu null.
  - `logout()` → `POST /auth/logout` (abaikan galat jaringan) lalu `TokenStore.logout()`.
  - `class AuthProvider extends ChangeNotifier { AuthProvider(AuthRepository repo); ApiUser? get user; bool get isLoggedIn; Future<void> load(); Future<void> login(String identifier, String password); Future<void> logout(); void clear(); }`
  - `Future<bool> requireLogin(BuildContext context)` — bila belum login, `pushNamed(AppRoutes.login, arguments: {'returnTo': true})` dan mengembalikan `true` hanya bila login berhasil (Login `pop(true)` saat `returnTo`).
  - `main.dart` menyediakan: `Provider<ApiClient>` (dengan `onUnauthorized` → `TokenStore.logout()` + `AuthProvider.clear()` + `navigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false)`), `Provider<AuthRepository>`, `ChangeNotifierProvider<AuthProvider>`. `MaterialApp.navigatorKey = appNavigatorKey` (global di `lib/core/app_router.dart`). `Provider<AppDb>` tetap sampai Task 15.

- [ ] **Step 1: Test gagal** `auth_repository_test.dart` (MockClient): login mengirim body `{"identifier":"0812…","password":"…","client":"mobile"}` dan menyimpan token (pakai `FlutterSecureStorage.setMockInitialValues({})`); 401 login → `ApiException` dengan pesan "Email/WA atau password salah."; register 409 → `ApiException.message == 'Data sudah terdaftar.'`; `currentUser()` tanpa token → null tanpa request; `currentUser()` 401 → null dan token terhapus; `resetPassword` mengirim `{email, code, password}`.
- [ ] **Step 2:** `flutter test test/data/auth_repository_test.dart` → FAIL.
- [ ] **Step 3: Implementasi repository + provider.**
- [ ] **Step 4: Layar.**
  - Splash: `await context.read<AuthProvider>().load()` lalu **selalu** ke `mainNav` (tamu boleh jelajah).
  - Login: label field identitas "Email atau No. WhatsApp"; panggil `AuthProvider.login`; galat → tampilkan `ApiException.message`; sukses → bila `returnTo` `pop(true)` selain itu `pushNamedAndRemoveUntil(mainNav)`.
  - Daftar: validasi lokal disamakan dengan server (sandi ≥ 8, ada huruf & angka; HP `^08\d{8,11}$`); panggil `register` lalu langsung `login`; galat field (`fields.phone` dst.) ditampilkan di field terkait.
  - Logout di profil memakai `AuthProvider.logout()`.
  - `test/widget_test.dart`: bungkus `KateringKitaApp` dengan `MultiProvider` berisi provider di atas (ApiClient dengan `MockClient` yang mengembalikan 401 untuk `/me`), `pumpAndSettle` melewati timer splash, `expect(find.byType(MaterialApp), findsOneWidget)`.
- [ ] **Step 5:** `flutter analyze` + `flutter test` → hijau.
- [ ] **Step 6: Commit** `feat(auth): login/daftar/logout ke backend, mode tamu`.

### Task 4: Lupa sandi via OTP email

**Files:** Modify `lib/screens/auth/forgot_password_screen.dart`, `verify_code_screen.dart`, `reset_password_screen.dart`. Test: `test/screens/forgot_flow_test.dart` (widget, MockClient).

**Interfaces:** Consumes `AuthRepository.forgotPassword/verifyCode/resetPassword` (Task 3). Argumen rute: forgot → verify `String email`; verify → reset `Map{'email': String, 'code': String}`; reset → login `String email`.

- [ ] **Step 1: Test gagal:** kode salah → teks "Kode salah atau sudah kedaluwarsa." tampil dan tidak pindah layar; kode benar → layar reset menerima `code`; reset sukses → kembali ke login dengan email terisi.
- [ ] **Step 2:** jalankan → FAIL.
- [ ] **Step 3:** Hapus jeda palsu (`Future.delayed`), panggil endpoint; "Kirim ulang" memanggil `forgotPassword` lagi (tampilkan pesan server, termasuk 429 apa adanya); hapus email fallback hardcoded; validasi sandi baru sama dengan daftar.
- [ ] **Step 4:** `flutter analyze` + `flutter test` → hijau.
- [ ] **Step 5: Commit** `feat(auth): lupa sandi OTP lewat backend`.

---

## Gelombang 2b — `feat/katalog`

### Task 5: CatalogRepository

**Files:** Create `lib/data/catalog_repository.dart`. Test `test/data/catalog_repository_test.dart`.

**Interfaces:**
- Consumes: `ApiClient`, `ProductModel`, `CategoryModel`, `PickupPoint`, `MerchantRef` (Task 1–2).
- Produces:
  - `class MenuPage { List<ProductModel> items; int total; int page; }`
  - `class MenuReview { int rating; String? comment; String customerName; DateTime createdAt; }`
  - `class MerchantProfile { int id; String slug; String businessName; String? description; String? logoUrl; String merchantTypeName; bool isOpen; String openTime; String closeTime; double ratingAvg; int ratingCount; List<PickupPoint> pickupPoints; }`
  - `class CatalogRepository { CatalogRepository(ApiClient api); Future<List<CategoryModel>> categories(); Future<List<PickupPoint>> pickupPoints(); Future<MenuPage> menus({String? q, String? category, String? merchant, String sort = 'popular', int page = 1, int limit = 20}); Future<ProductModel> menuDetail(int id); Future<List<MenuReview>> reviews(int menuId, {int page = 1}); Future<MerchantProfile> merchant(String slug); }`
  - Kategori & titik temu di-cache di memori setelah panggilan pertama.

- [ ] **Step 1: Test gagal:** query string `menus(q: 'lumpia', category: 'danusan', sort: 'price_asc')` → `/menus?q=lumpia&category=danusan&sort=price_asc&page=1&limit=20`; parameter null tidak dikirim; `categories()` dua kali → satu request; 404 `menuDetail` → `ApiException` "Menu tidak ditemukan.".
- [ ] **Step 2–4:** FAIL → implementasi → PASS + analyze bersih.
- [ ] **Step 5: Commit** `feat(katalog): CatalogRepository`.

### Task 6: Home, Cari, kartu menu

**Files:** Modify `lib/screens/home/home_screen.dart`, `lib/screens/home/search_screen.dart`, `lib/widgets/food_card.dart`, `lib/main.dart` (`Provider<CatalogRepository>`). (Shim `ProductData` tetap ada — masih dipakai favorit/AI.) Test `test/screens/home_screen_test.dart`.

**Interfaces:** Consumes `CatalogRepository` (Task 5). `FoodGridCard` navigasi profil toko dengan `arguments: product.merchant.slug` (String slug).

- [ ] **Step 1: Test gagal (widget, MockClient):** `/menus` kosong → teks "Belum ada menu yang tersedia saat ini." dan tidak ada exception; dua menu → dua `FoodGridCard`; chip kategori dari `/meta/categories` (+ chip "Semua" di depan); tap chip → request `/menus?category=<slug>`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi.** Home: chip kategori dari API (ganti filter lokal `_filteredProducts`), grid dari `menus(category:)`, tarik-untuk-refresh, keadaan memuat & galat (tombol "Coba lagi"). Banner dibiarkan; tap banner → `pushNamed(AppRoutes.search)` (bukan produk dummy). Cari: `TextField` kosong dengan hint, `onChanged` debounce 400 ms → `menus(q:)`; urutan pakai `sort` (`popular|rating|price_asc|price_desc`) bila UI sudah punya kontrol urut, kalau tidak, cukup `popular`; hapus `_searchResults` hardcoded; keadaan kosong "Menu tidak ditemukan.".
- [ ] **Step 4:** analyze + test → hijau.
- [ ] **Step 5: Commit** `feat(katalog): home & cari dari backend`.

### Task 7: Detail menu & profil toko

**Files:** Modify `lib/screens/home/product_detail_screen.dart`, `lib/screens/home/store_profile_screen.dart`; hapus `lib/models/vendor_model.dart` bila tak ada pemakai lain (Task 8 membaca nilainya dari basis `feat/api-fondasi`, jadi aman dihapus di branch ini). Test `test/screens/product_detail_test.dart`.

**Interfaces:**
- Consumes `CatalogRepository.menuDetail/reviews/merchant/menus(merchant:)`.
- Detail menerima `arguments: ProductModel` (MenuCard) lalu memuat `menuDetail(id)`; profil toko menerima `arguments: String slug`.
- Produces untuk Task 9: detail menyimpan `MenuOption? _selectedOption` (null = tanpa opsi) dan qty; tombol utama memanggil callback yang di Task 9 diisi `CartProvider.add`. Di task ini tombol utama tetap ke checkout dengan `arguments: ProductModel` (perilaku lama) supaya alur tetap jalan.

- [ ] **Step 1: Test gagal:** toko tutup (`merchant.is_open: false`) → teks "Toko sedang tutup" tampil dan tombol utama nonaktif; `badge: sold_out` → tombol nonaktif bertuliskan "Habis"; opsi dari `options[]` tampil sebagai pilihan dengan tambahan harga ("+ Rp 2.000" bila `extra_price > 0`); ulasan dari `/menus/:id/reviews` tampil (nama tersamar apa adanya).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi.** Galeri: hanya `imageUrl` (hapus 2 gambar aset hardcoded). Kartu toko: `merchant.businessName`, `logoUrl` via `MenuImage`, `ratingAvg/ratingCount` dari `merchant(slug)` (dimuat malas), jam buka `openTime–closeTime WIB`. Tap → profil toko dengan slug. Favorit (`LikedStore`) dibiarkan sampai rencana kedua. Profil toko: header/menu/rating/jam/titik temu dari API; bagian tanpa data (jarak, ETA, halal, prime, promo toko, ulasan toko, banner) dibiarkan tampil statis **tanpa** angka palsu yang berasal dari `VendorData` — sembunyikan widget yang memerlukan field yang tidak ada; tombol WhatsApp toko disembunyikan (API publik tidak memberi nomor). Tombol checkout di bawah → menu pertama tidak lagi dipakai; diganti "Lihat keranjang" di Task 9 (di task ini sembunyikan).
- [ ] **Step 4:** analyze + test → hijau.
- [ ] **Step 5: Commit** `feat(katalog): detail menu & profil toko dari backend`.

---

## Gelombang 2c — `chore/seed-toko-production`

### Task 8: Skrip seed 5 toko mobile ke production

**Files:** Create `tool/seed_toko.dart`, `tool/seed_toko.json`, `tool/README.md` (cara jalan). Test `test/tool/seed_mapping_test.dart`.

**Interfaces:**
- Dijalankan: `dart run tool/seed_toko.dart [--api <url>]` (bawaan URL production). Interaktif lewat stdin: identitas+sandi admin (input sandi tanpa gema: `stdin.echoMode = false`), lalu per toko: no HP penjual (bawaan dari JSON) dan sandi penjual. Tidak menulis kredensial ke berkas.
- `seed_toko.json`: daftar toko dari `vendor_model.dart` — `business_name`, `full_name` (pemilik, mis. "Pemilik <toko>"), `phone` (nomor karangan dinormalkan `62…` → `08…`), `merchant_type_id` (Diego Katering 1, Martabak Pecenongan 2, Dapur Slamet 1, Surgawi Bakery 2, Dapur Bu Tima 2), `address` (`fullAddress`), `open_time`/`close_time` (dari `openHours`), `pickup_point_ids: [1,2,3]`, `hold_minutes: 30`, `description`, `logo` (path aset), dan `menus[]`: `name`, `category_slug` (lumpia/risoles/pastel/donat-snack → `danusan`/`snack`, martabak → `martabak`, nasi/paket → `nasi-box`; tulis eksplisit per menu), `price` (dari mobile), `hpp` (= `price * 0.6` dibulatkan ke 500 terdekat ke bawah), `daily_quota: 50`, `prep_minutes: 15`, `unit_label` ("porsi", atau "isi 6"/"isi 4" sesuai nama), `min_order_qty: 1`, `is_preorder: false`, `preorder_days: 0`, `description`, `options[{name, extra_price: 0}]` dari opsi mobile, `image` (path aset).
- Langkah per toko (idempoten): coba login penjual (`client: "mobile"`) → bila 401, `POST /auth/merchant/register`; admin `POST /admin/merchants/:id/verify` bila status bukan `verified` (cek lewat `GET /me` penjual); penjual `PATCH /merchant/profile {open_time, close_time, pickup_point_ids, hold_minutes, description}`; logo & menu: `POST /merchant/uploads {purpose, content_type:"image/png", size}` → `PUT upload_url` body bytes persis dengan `Content-Type: image/png` → `public_url`; `GET /merchant/menus` → lewati menu yang namanya sudah ada; `POST /merchant/menus`.
- Fungsi murni yang dites: `String normalizePhone(String)` (`6281234567890` → `081234567890`), `({String open, String close}) parseHours(String)` (`'06:30 - 17:00 WIB'` → `06:30`/`17:00`), `int hppFor(int price)` (`25000` → `15000`, `16000` → `9500`).

- [ ] **Step 1: Test gagal** untuk tiga fungsi murni dengan nilai di atas; plus `seed_toko.json` dapat diparse dan setiap menu punya `category_slug` ∈ {nasi-box, ayam, martabak, snack, minuman, paket-acara, danusan} dan `price > hpp`.
- [ ] **Step 2:** FAIL. **Step 3:** implementasi. **Step 4:** test hijau, `dart analyze tool` bersih.
- [ ] **Step 5:** **Jangan jalankan skrip ke production** — hanya pemilik yang menjalankan (via `! dart run tool/seed_toko.dart`) setelah R2 beres.
- [ ] **Step 6: Commit** `chore(seed): skrip toko mobile ke production`.

---

## Gelombang 3 — `feat/keranjang-checkout` (basis: merge `feat/auth` + `feat/katalog`)

### Task 9: CartProvider multi-menu satu toko + tombol keranjang

**Files:** Modify `lib/providers/cart_provider.dart`, `lib/models/cart_item.dart`, `lib/screens/home/product_detail_screen.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/home/store_profile_screen.dart`. Create `lib/widgets/cart_button.dart`. Test `test/providers/cart_provider_test.dart`.

**Interfaces:**
- Produces:
  - `class CartItem { final ProductModel menu; final MenuOption? option; int qty; String get key => '${menu.id}:${option?.id ?? 0}'; int get estimatedLineTotal => (menu.price + (option?.extraPrice ?? 0)) * qty; }` (estimasi hanya untuk tampilan sebelum quote).
  - `enum AddResult { added, differentMerchant }`
  - `class CartProvider extends ChangeNotifier { List<CartItem> get items; int? get merchantId; int get count; bool get hasPreorder; int get maxPreorderDays; AddResult add(ProductModel menu, {MenuOption? option, int qty = 1}); void replaceWith(ProductModel menu, {MenuOption? option, int qty = 1}); void setQty(String key, int qty); void remove(String key); void clear(); List<Map<String, dynamic>> toQuoteItems(); }`
  - `toQuoteItems()` → `[{'menu_id': id, 'qty': qty, 'option_ids': option == null ? [] : [option.id]}]`.
  - `CartButton` — ikon keranjang + lencana `count`, tap → `pushNamed(AppRoutes.checkout)` (tanpa argumen).

- [ ] **Step 1: Test gagal:** menambah menu sama + opsi sama → qty bertambah, satu baris; opsi beda → dua baris; menu toko lain → `AddResult.differentMerchant` dan keranjang tidak berubah; `replaceWith` mengosongkan lalu menambah; `setQty(key, 0)` menghapus baris; `hasPreorder`/`maxPreorderDays` dari `isPreorder`/`preorderDays`; `toQuoteItems` persis seperti di atas.
- [ ] **Step 2–4:** FAIL → implementasi → PASS.
- [ ] **Step 5: UI:** detail menu tombol utama "Tambah ke Keranjang" → `add`; `differentMerchant` → dialog "Keranjang berisi menu dari toko lain. Kosongkan dan ganti?" (Ya → `replaceWith`); sukses → snackbar "Ditambahkan ke keranjang" + tetap di halaman. `CartButton` dipasang di app bar Home, detail menu, profil toko (ganti tombol checkout bawah di profil toko dengan "Lihat Keranjang (n)" bila `count > 0`). Tombol tambah nonaktif bila `!menu.canOrder`.
- [ ] **Step 6:** analyze + test hijau. **Commit** `feat(keranjang): keranjang multi-menu satu toko`.

### Task 10: Checkout dari keranjang — quote, titik temu + peta, waktu ambil, metode bayar, buat pesanan

**Files:**
- Create: `lib/data/order_repository.dart`, `lib/core/pickup_time.dart`, `lib/screens/orders/pickup_point_picker_screen.dart`
- Modify: `lib/screens/orders/checkout_screen.dart`, `lib/widgets/payment_method_tile.dart` (enum `PaymentMethod { online, virtualAccount }`, `String get apiValue` → `'online'`/`'va'`), `lib/main.dart` (`Provider<OrderRepository>`)
- Test: `test/data/order_repository_test.dart`, `test/core/pickup_time_test.dart`, `test/screens/checkout_screen_test.dart`

**Interfaces:**
- Consumes: `CartProvider` (Task 9), `CatalogRepository.menuDetail` (pickup points toko), `AuthProvider.user`, `requireLogin`.
- Produces (dipakai Task 11–14):
  - `class OrderRepository { OrderRepository(ApiClient api); Future<Quote> quote(Map<String, dynamic> body); Future<OrderApiModel> create(Map<String, dynamic> body, {required String idempotencyKey}); Future<OrderApiModel> get(String code); Future<OrderApiModel> createVa(String code, String bank); Future<OrderApiModel> startOnline(String code); Future<({List<OrderApiModel> items, int total})> list({required String tab, String? q, int page = 1, int limit = 20}); Future<OrderApiModel> cancel(String code, {String? reason}); Future<OrderApiModel> complete(String code); Future<({String waNumber, String message, String url})> whatsapp(String code); Future<({Map<String, dynamic> request, Quote quote})> reorder(String code); Future<List<int>> review(String code, List<({int menuId, int rating, String? comment})> items); }`
  - `DateTime earliestPickupUtc(DateTime nowUtc, int preorderDays)` — 00:00 WIB (UTC+7) pada (tanggal WIB hari ini + `preorderDays`), dikembalikan dalam UTC.
  - `bool isPickupAllowed(DateTime pickupUtc, DateTime nowUtc, int preorderDays)` — `> now`, `<= now + 7 hari`, dan bila `preorderDays > 0` `>= earliestPickupUtc`.
  - Checkout menavigasi ke `AppRoutes.payment` dengan `arguments: OrderApiModel` (bentuk lama `Map` dibuang).

- [ ] **Step 1: Test gagal:**
  - `pickup_time_test`: `earliestPickupUtc(DateTime.utc(2026,11,12,18,0), 1)` (= 13 Nov 01:00 WIB) → `DateTime.utc(2026,11,13,17,0)` (14 Nov 00:00 WIB); `earliestPickupUtc(DateTime.utc(2026,11,12,3,0), 2)` → `DateTime.utc(2026,11,13,17,0)`; `isPickupAllowed` menolak lewat 7 hari dan masa lalu.
  - `order_repository_test`: `create` mengirim header `Idempotency-Key` persis; `quote` mengembalikan `warnings`; 409 `MERCHANT_CLOSED` → `ApiException.code == 'MERCHANT_CLOSED'`; `list(tab: 'active')` → `/me/orders?tab=active&page=1&limit=20`.
  - `checkout_screen_test` (MockClient): keranjang 2 baris → quote dipanggil dan total yang tampil = `total` dari server (bukan estimasi lokal); keranjang berisi pre-order → pilihan "Secepatnya" nonaktif dan tombol bayar nonaktif sampai tanggal dipilih; opsi tunai tidak ada di layar; respons `POST /orders` timeout lalu tombol ditekan lagi → kedua request membawa `Idempotency-Key` yang **sama**; respons 409 `OUT_OF_STOCK` dengan `fields["items.0.qty"]` → pesan "Sisa 1 porsi." tampil di baris pertama.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi repository + pickup_time.**
- [ ] **Step 4: Implementasi layar checkout** (tampilan kartu/section dipertahankan):
  - Masuk checkout tanpa login → `requireLogin`; batal → kembali.
  - Isi: daftar baris keranjang (gambar `MenuImage`, nama, opsi, stepper qty, hapus); kosong → keadaan kosong + tombol ke Home.
  - Titik temu: ambil `merchant.pickupPoints` lewat `menuDetail(items.first.menu.id)`; bawaan `user.favoritePickupPointId` bila dilayani, kalau tidak titik pertama. Tap → `PickupPointPickerScreen(points, selectedId)` = `FlutterMap` (OSM, pusat kampus UB `LatLng(-7.9526, 112.6145)`, zoom 16, tanpa pin per titik) di atas + `ListView` titik temu di bawah; `pop(PickupPoint)`. Peta mini checkout lama dibiarkan sebagai latar dengan nama titik temu terpilih.
  - Waktu ambil: "Secepatnya" atau pilih tanggal+jam (`showDatePicker` + `showTimePicker`, ditampilkan WIB); pre-order memaksa tanggal ≥ `earliestPickupUtc`.
  - Nama & no HP: diisi dari `user` sebagai **nilai awal** yang bisa diubah; kosong → kirim `null`. Catatan: kosong secara bawaan (hapus isian 'Sambal dipisah…'), placeholder lewat `hintText`.
  - Kode promo: field opsional → `promo_code`; 422 → tampilkan pesan di field.
  - Ringkasan: `subtotal`, `discount`, `service_fee`, `total` dari `quote`; quote diulang (debounce 400 ms) saat qty/opsi/titik temu/waktu/promo berubah; tampilkan `warnings[].message`.
  - Metode bayar: dua `PaymentMethodTile` — "QRIS / E-Wallet" (`online`) dan "Virtual Account" (`va`). Timer hiasan sebelum pesanan dihapus dari checkout (pesanan belum ada).
  - Konfirmasi: buat `idempotencyKey` sekali per niat checkout (disimpan di state; dibuat ulang hanya setelah sukses atau setelah isi keranjang berubah); `create(body + payment_method)`; sukses → `cart.clear()` → `pushReplacementNamed(AppRoutes.payment, arguments: order)`; galat → pesan server.
- [ ] **Step 5:** analyze + test hijau.
- [ ] **Step 6: Commit** `feat(checkout): checkout keranjang, titik temu, waktu ambil, buat pesanan`.

---

## Gelombang 4a — `feat/bayar-midtrans`

### Task 11: Layar bayar VA + Snap WebView + polling status

**Files:**
- Run: `flutter pub add webview_flutter`
- Create: `lib/screens/orders/snap_webview_screen.dart`, `lib/core/payment_poller.dart`
- Modify: `lib/screens/orders/payment_screen.dart`
- Test: `test/core/payment_poller_test.dart`, `test/screens/payment_screen_test.dart`

**Interfaces:**
- Consumes: `OrderRepository.get/createVa/startOnline` (Task 10), argumen `OrderApiModel`.
- Produces:
  - `enum PaymentOutcome { waiting, paid, expired, cancelled }` dan `PaymentOutcome outcomeOf(OrderApiModel o)` — `paid` bila `o.isPaid`; `expired` bila `status == 'expired'` atau (`status == 'holding'` dan `secondsLeft == 0`); `cancelled` bila `status == 'cancelled'`; selain itu `waiting`.
  - `class PaymentPoller { PaymentPoller(OrderRepository repo, String code, {Duration interval = const Duration(seconds: 5)}); Stream<OrderApiModel> start(); void stop(); }` — berhenti sendiri saat `outcomeOf != waiting`.
  - `SnapWebViewScreen(url)` → `pop()` saat URL memuat `transaction_status=` atau `status_code=` atau pengguna menekan tutup.

- [ ] **Step 1: Test gagal:** `outcomeOf` untuk keempat kasus; poller memancarkan 3 kali lalu berhenti ketika respons ketiga `payment_status: paid`; layar bayar VA: argumen order `va` tanpa `payment.va` → memanggil `POST /orders/:code/va {bank}` setelah bank dipilih dan menampilkan `va_number` dari respons; `hold_until` lewat (`seconds_left: 0`) → teks "Batas waktu pesanan sudah habis." dan tidak ada lembar sukses; `payment_status: paid` → lembar sukses tampil.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi.**
  - Hapus `_QrisPatternPainter`, NMID hardcoded, `_getVirtualAccountNumber` palsu, jeda 1200 ms, `db.addOrder`, bagian COD.
  - Timer hitung mundur dari `hold_until` server (bukan 3600 lokal).
  - VA: pilih bank (BCA/BNI/BRI — `_bankCodes` dipertahankan untuk tampilan) → `createVa` sekali → tampilkan `va.vaNumber`, bank, `total`, batas waktu; salin nomor.
  - Online: tombol "Bayar dengan QRIS / E-Wallet" → `startOnline` → buka `SnapWebViewScreen(payment.paymentUrl)`; setelah kembali, langsung `get(code)`.
  - Polling `PaymentPoller` selama layar terbuka (dan sekali saat `AppLifecycleState.resumed`).
  - `paid` → lembar sukses (tombol "Kirim Rincian ke WhatsApp" → `AppRoutes.whatsappGenerator` dengan `arguments: order.code`; "Lihat Pesanan" → main nav tab Pesanan). `expired`/`cancelled` → pesan + tombol kembali ke Beranda.
  - Ringkasan pesanan dari `order.items` (nama, qty, `lineTotal`), `order.total`.
- [ ] **Step 4:** analyze + test hijau (Android: `webview_flutter` butuh `minSdk` ≥ yang disyaratkan paketnya; bila `flutter.minSdkVersion` kurang, **laporkan**, jangan ubah versi Gradle).
- [ ] **Step 5: Commit** `feat(bayar): VA & Snap Midtrans dengan status dari server`.

### Task 12: Generator WhatsApp dari server

**Files:** Modify `lib/screens/orders/whatsapp_generator_screen.dart`. Test `test/screens/whatsapp_screen_test.dart`.

**Interfaces:** argumen rute = `String code`; consumes `OrderRepository.whatsapp`, `url_launcher.launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`.

- [ ] **Step 1: Test gagal:** pesan dari `GET /orders/:code/whatsapp` tampil di kotak teks; tombol "Buka WhatsApp" memanggil launcher dengan `url` server (pakai `UrlLauncherPlatform` palsu); tidak ada dialog "Pesanan Terkirim" palsu.
- [ ] **Step 2–4:** FAIL → implementasi (salin tetap ada; nama toko & total dari pesan server) → hijau.
- [ ] **Step 5: Commit** `feat(wa): pesan WhatsApp dari server`.

---

## Gelombang 4b — `feat/pesanan`

### Task 13: Daftar pesanan dari server + batal/selesai/pesan lagi

**Files:** Modify `lib/screens/orders/orders_screen.dart`, `active_orders_screen.dart`, `completed_orders_screen.dart`. Create `lib/widgets/order_status_label.dart`. Test `test/screens/orders_screen_test.dart`.

**Interfaces:**
- Consumes: `OrderRepository.list/cancel/complete/reorder`, `CatalogRepository.menuDetail`, `CartProvider.replaceWith/add`, `requireLogin`.
- `String orderStatusLabel(OrderApiModel o)`: holding+unpaid/pending → "Menunggu pembayaran", confirmed → "Dikonfirmasi", cooking → "Sedang dimasak", ready → "Siap diambil", completed → "Selesai", cancelled → "Dibatalkan" (+ `cancelledBy`: "oleh penjual"/"oleh sistem"), expired → "Kedaluwarsa".

- [ ] **Step 1: Test gagal:** tab Aktif memanggil `?tab=active`; tombol "Batalkan" hanya tampil bila `canCancel`, "Selesaikan Pesanan" hanya bila `canComplete`; batal sukses → daftar dimuat ulang; tamu → tampilan ajakan masuk, tanpa request.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi.** Tab Aktif/Selesai/Dibatalkan = `list(tab:)` (tab "cancelled" juga memuat expired); cari → `q` (debounce 400 ms); tarik-untuk-refresh + polling 15 dtk saat layar terlihat; kartu: gambar menu pertama (`MenuImage` via `menuDetail` tidak perlu — pakai gambar pengganti bila tak ada URL; **jangan** `getProductByName`), `code`, nama menu (`items.first.menuName` + "+n menu lain"), total, label status, sisa waktu dari `secondsLeft` bila holding. Holding + belum lunas → tombol "Lanjutkan Bayar" → `get(code)` → `AppRoutes.payment` (arguments: order). "Buka WhatsApp" → `AppRoutes.whatsappGenerator` (arguments: code). "Pesan Lagi" → `reorder(code)` → untuk tiap item `menuDetail(menu_id)` → `cart.replaceWith` untuk baris pertama lalu `add` sisanya (opsi dari `option_ids`) → `pushNamed(AppRoutes.checkout)`; galat (toko tutup) → pesan server. `active_orders_screen`/`completed_orders_screen` memakai komponen yang sama dengan tab tetap.
- [ ] **Step 4:** analyze + test hijau.
- [ ] **Step 5: Commit** `feat(pesanan): daftar & aksi pesanan dari server`.

### Task 14: Ulasan pesanan selesai

**Files:** Create `lib/widgets/review_sheet.dart`. Modify `lib/screens/orders/orders_screen.dart`, `completed_orders_screen.dart`. Test `test/widgets/review_sheet_test.dart`.

**Interfaces:** `Future<bool?> showReviewSheet(BuildContext, OrderApiModel order)` — satu baris per item (bintang 1–5 + komentar ≤ 500), kirim `OrderRepository.review`; tombol "Beri Ulasan" tampil hanya bila `canReview`.

- [ ] **Step 1: Test gagal:** kirim tanpa bintang → tombol kirim nonaktif; 409 "Menu ini sudah diulas." tampil; sukses → sheet tertutup dengan `true` dan daftar dimuat ulang.
- [ ] **Step 2–4:** FAIL → implementasi → hijau.
- [ ] **Step 5: Commit** `feat(pesanan): ulasan menu untuk pesanan selesai`.

---

## Akhir — `integrasi/alur-pesan`

### Task 15: Gabung, bersihkan Drift dari jalur pesanan, perbarui README

**Files:** merge branch gelombang 2–4; Modify `README.md` (bagian 4C, 5 Kasus 4), `lib/main.dart`; Delete bila tak ada pemakai lagi: `lib/data/app_database.dart`, `lib/data/app_database.g.dart`, dependency `drift`, `drift_flutter`, `drift_dev`, `build_runner` (cek dengan `grep -r "AppDb\|app_database" lib test`; bila masih dipakai layar di luar rencana ini, tunda dan catat).

- [ ] **Step 1:** `git checkout -b integrasi/alur-pesan feat/keranjang-checkout && git merge --no-ff feat/bayar-midtrans feat/pesanan` (selesaikan konflik di `main.dart`/`app_router.dart` dengan mempertahankan kedua sisi).
- [ ] **Step 2:** Hapus Drift bila tidak ada pemakai; `flutter pub get`.
- [ ] **Step 3:** README: ganti 4C ("data disimpan di SQLite…") dengan cara kerja baru (base URL, `--dart-define=API_BASE_URL`, akun, Midtrans sandbox, cara menjalankan seed); hapus Kasus 4 bila Drift sudah hilang.
- [ ] **Step 4:** `flutter analyze` bersih, `flutter test` hijau — tempel output.
- [ ] **Step 5: Commit** `chore: integrasi alur pesan, bersihkan Drift, perbarui README`.
- [ ] **Step 6:** Laporkan ke pemilik: daftar branch + commit, hasil test, langkah uji manual (seed → daftar → pesan → bayar sandbox → cek dashboard penjual), dan hal yang tertunda ke rencana kedua (favorit, profil, notifikasi, AI, salin ke `mobile/` monorepo).
