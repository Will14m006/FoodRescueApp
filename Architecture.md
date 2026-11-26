# Architecture: Food Rescue App

## 1. Purpose
Membantu restoran atau kafe (Mitra) menjual makanan surplus layak konsumsi di akhir jam operasional kepada pengguna (Pembeli) dengan harga diskon. Aplikasi ini mengelola ketersediaan stok secara *real-time* dan menggunakan sistem validasi kode *pick-up* untuk pengambilan di tempat.

## 2. Tech Stack
* **Frontend (Mobile):** Flutter (Dart)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Backend:** Dart (`shelf` + `shelf_router`) di folder `backend/` — sudah berjalan, bukan rencana
* **Database Pusat:** SQLite via `drift` (mode WAL, satu file `data/food_rescue.db`)
* **Autentikasi:** JWT (`dart_jsonwebtoken`) + `bcrypt`; token disimpan di perangkat, password tidak pernah
* **Penyimpanan Lokal (Mobile):** SharedPreferences (`SharedPreferencesAsync`) — hanya sesi + foto bukti
* **Advanced Features (P7):** Autentikasi (HTTP ke backend sendiri), Lokasi (`geolocator`), Kamera (`image_picker`)
* **Environment:** Flutter SDK 3.47, Dart 3.13, VS Code

## 3. Code Rules
* Do not add comments unless truly necessary.
* Use PascalCase for all classes, enums, and widget components.
* Local variables may use camelCase.
* Keep code lines below 150 characters where practical.
* Use a clean and simple folder structure.
* Pisahkan tanggung jawab antara **widget (UI)**, **notifier/use case (state management)**, dan **repository (data source)**.

## 4. Main Entities

### 1. Merchant
* Id
* Name
* StoreName
* Address
* CreatedAt

### 2. Buyer
* Id
* Name
* Email
* CreatedAt

### 3. SurplusFood
* Id
* MerchantId
* Name
* OriginalPrice
* DiscountPrice
* Quota
* IsActive
* CreatedAt

### 4. Order
* Id
* BuyerId
* SurplusFoodId
* PickupCode
* Status
* CreatedAt

## 5. Database Rules
* `PickupCode` must be unique across all active orders.
* Never hard-delete existing order data.
* Never replace existing transaction records.
* When an `Order` is created, automatically decrement the `Quota` in `SurplusFood`.

## 6. Mobile Features

1. **Authentication (Login)**
   * Login ke backend sendiri `POST /auth/login`. Akun demo dibuat `tool/seed.dart`
     (`buyer@foodrescue.id` / `toko@foodrescue.id` / `admin@foodrescue.id`, password dari `SEED_PASSWORD`).
   * Satu layar dua mode: masuk dan daftar (pilih peran pembeli atau merchant; admin tidak bisa didaftarkan).
   * Sesi disimpan sebagai token saja (`SharedPreferencesAsync`), dipulihkan lewat `GET /auth/me`.
   * Menampilkan state loading, error (password salah / jaringan), dan sukses.
   * Data user (nama, email, peran) dipakai di halaman profil; logout dengan dialog konfirmasi.
2. **Lokasi / GPS** (advanced feature)
   * Banner lokasi di dashboard: koordinat titik jemput, tombol aktifkan & perbarui.
   * Menangani izin: `granted`, `denied`, `deniedForever` (buka Settings), `serviceDisabled`.
   * Repository tidak pernah melempar exception — semua kondisi jadi `LocationResult`.
3. **Kamera** (advanced feature)
   * Foto bukti pengambilan, **hanya untuk pembeli** dan **tidak mengubah status**.
   * User membatalkan kamera = kondisi normal (`cancelled`), bukan error.
   * Tombol Konfirmasi non-aktif sampai foto ada.
   * Foto disimpan lokal per akun (`ProofPhotoStore`); backend tidak menyimpan gambar.
4. **Katalog Surplus (Buyer Feed)**
   * Menampilkan daftar `SurplusFood` yang aktif dan masih memiliki kuota.
   * **Data diambil dari backend sendiri** (`GET /foods`) melalui repository + model,
     lengkap dengan state loading / empty / error / retry.
   * Pencarian makanan berdasarkan nama atau nama toko.
5. **Booking / Pemesanan**
   * Form pemesanan dengan validasi jumlah (nama tidak ditanyakan — server memakai nama akun).
   * **Pesanan dikirim ke backend** (`POST /orders`); kode *pick-up* dibuat server dengan
     `Random.secure` (contoh `RESCUE-7KQ2XM`). Harga & total dihitung server.
   * Tombol pesan *disabled* saat proses submit untuk mencegah double-tap.
6. **Orders Screen (Status & Riwayat Pesanan)**
   * Status Pesanan: lihat status + aksi sesuai peran.
     Pembeli: lampirkan bukti foto (lokal) atau batalkan. Merchant/admin: verifikasi
     kode pick-up (menjadi `SELESAI`) atau batalkan. Pesanan tidak bisa dihapus (never hard-delete).
   * Riwayat Pesanan: read-only, data dari server (`GET /orders`).
   * Status pesanan **selalu dari server** supaya pembeli, merchant, dan admin melihat hal yang sama.
7. **Validasi Pesanan (Mitra)**
   * Merchant memasukkan kode pick-up dari pembeli. Kode salah → 422, status tidak berubah.
   * Pembeli tidak bisa menyelesaikan pesanannya sendiri (server menolak 403).
8. **Order Status rules:**
   * `PENDING`: Order created, waiting for pickup.
   * `COMPLETED`: Food picked up and code validated.
   * `CANCELLED`: Order cancelled by buyer or merchant.

## 7. Mobile Screens

1. **Login Screen**
   * Input email & password + validasi, state loading/error, pindah ke dashboard saat sukses.
   * Mode daftar dengan field nama dan pilihan peran (pembeli / merchant).
   * Alamat server yang dituju ditampilkan supaya jelas saat demo.
2. **Home Screen (penentu peran)**
   * Membaca peran dari token lalu menampilkan dashboard yang sesuai: pembeli, merchant, atau admin.
   * Tanpa sesi → kembali ke layar masuk.
3. **Dashboard Screen (Katalog Surplus / Buyer Feed)**
   * Banner lokasi (advanced feature GPS) di atas search bar.
   * Daftar makanan surplus dalam bentuk card.
   * Setiap card memiliki informasi: toko, menu, harga asli (coret), harga diskon, sisa kuota, dan tombol "Pesan".
4. **Merchant Dashboard Screen**
   * Setup profil toko (nama toko), lalu statistik: pesanan, porsi terjual, pendapatan, sisa porsi.
   * Daftar pesanan menunggu verifikasi (masukkan kode pick-up) + tombol batalkan.
   * Kelola stok makanan dan tambah makanan baru.
5. **Admin Dashboard Screen**
   * `GET /admin/stats` + daftar pengguna dengan filter peran.
   * Admin tidak bisa mengubah peran siapa pun dari aplikasi (endpoint itu tidak ada).
6. **Booking Screen (Pemesanan)**
   * Rincian makanan yang dipilih.
   * Form detail pemesanan (jumlah) dengan validasi + dialog konfirmasi.
7. **Orders Screen (Riwayat Pesanan)**
   * Daftar pesanan dari server, **read-only**.
8. **Order Status Screen (Status Pesanan)**
   * Daftar pesanan + aksi Update sesuai peran. Tidak ada aksi hapus.
   * Pembeli: dialog bukti foto kamera (advanced feature), atau batalkan.
   * Merchant/admin: dialog verifikasi kode pick-up, atau batalkan.
9. **Profile Screen**
   * Nama, email, dan peran user dari sesi + tombol Keluar (dialog konfirmasi).
   * Edit profil: hanya nama & email (`PATCH /auth/me`).

## 8. UI Requirements
* Use Indonesian language for all labels, buttons, messages, and validation.
* Material 3 design dengan font "Plus Jakarta Sans" (modern, mobile-first).
* Palet warna terpusat di `lib/core/theme/app_colors.dart` (hijau utama, oranye aksen).
* Layout adaptif: grid 1 kolom di mobile, 2+ kolom di layar lebar (desktop/tablet).
* Clean and simple UI with cards, forms, empty states, and error states with retry.
* Skeleton shimmer saat loading (bukan spinner biasa) untuk kesan aplikasi cepat.
* Use status badge colors:
  * COMPLETED: green
  * PENDING: orange
  * CANCELLED: red

## 9. Project Structure

```
food_rescue_app/
├── lib/
│   ├── main.dart                      # Entry point + ProviderScope + routing
│   ├── core/                          # Design system (tema, warna, tipografi)
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_spacing.dart
│   │   │   ├── app_text_styles.dart
│   │   │   └── app_theme.dart
│   │   ├── ui/
│   │   │   └── app_feedback.dart      # P8: snackbar sukses/error/info
│   │   ├── network/
│   │   │   ├── api_client.dart        # Satu-satunya jalan keluar HTTP
│   │   │   └── api_exception.dart     # Error yang aman ditampilkan (ada statusCode)
│   │   ├── config/
│   │   │   └── api_config.dart        # Base URL (--dart-define / default per platform)
│   │   ├── session/
│   │   │   └── session_store.dart     # Sesi (token saja) di SharedPreferencesAsync
│   │   ├── utils/
│   │   │   ├── formatters.dart        # P9: format Rupiah & tanggal (satu sumber)
│   │   │   └── app_log.dart           # P10: log runtime (dart:developer)
│   │   └── validation/
│   │       └── validators.dart        # P9: aturan input (required/minLength/email/quantity)
│   ├── routes/                        # Definisi named routes
│   │   └── app_routes.dart
│   ├── screens/                       # Lapisan UI (widget)
│   │   ├── login_screen.dart          # Masuk + daftar (satu layar)
│   │   ├── home_screen.dart           # Pemilih dashboard per peran
│   │   ├── dashboard_screen.dart      # Fitur 1: Katalog Surplus (pembeli)
│   │   ├── merchant_dashboard_screen.dart
│   │   ├── admin_dashboard_screen.dart
│   │   ├── booking_screen.dart        # Fitur 2: Booking / Pemesanan
│   │   ├── order_status_screen.dart   # Status Pesanan (aksi sesuai peran)
│   │   ├── orders_screen.dart         # Riwayat Pesanan (read-only)
│   │   ├── profile_screen.dart
│   │   └── profile_form_screen.dart   # P9: ProfileForm (input + status UI saja)
│   ├── widgets/                       # Reusable component
│   │   ├── primary_button.dart
│   │   ├── app_text_field.dart
│   │   ├── food_card.dart
│   │   ├── food_card_skeleton.dart
│   │   ├── empty_state_view.dart
│   │   ├── error_state_view.dart
│   │   ├── location_banner.dart       # P7: UI lokasi (advanced #2)
│   │   ├── pickup_proof_dialog.dart   # P7: UI kamera (advanced #3)
│   │   ├── responsive_body.dart       # P8: layout adaptif + breakpoints
│   │   ├── circle_icon_button.dart    # P8: tombol ikon aksesibel (48px + tooltip)
│   │   └── order_card.dart            # P9: card pesanan + StatusBadge (dipakai 2 layar)
│   ├── models/                        # Model data
│   │   ├── surplus_food_model.dart
│   │   ├── order_model.dart
│   │   └── user_role.dart             # Sama persis dengan UserRole di backend
│   ├── providers/                     # State management (Riverpod notifier)
│   │   ├── auth_provider.dart         # Sesi + ApiClient + SessionStore
│   │   ├── location_provider.dart     # P7: lokasi + izin (advanced #2)
│   │   ├── camera_provider.dart       # P7: kamera + batal (advanced #3)
│   │   ├── catalog_provider.dart
│   │   ├── booking_provider.dart
│   │   ├── orders_provider.dart       # Pesanan dari server + foto lokal
│   │   ├── merchant_provider.dart     # Dashboard merchant
│   │   ├── admin_provider.dart        # Dashboard admin
│   │   └── profile_provider.dart      # P9: state update profil (AsyncNotifier)
│   └── repositories/                  # Sumber data
│       ├── auth_repository.dart       # /auth/*
│       ├── surplus_food_repository.dart # GET /foods
│       ├── order_repository.dart      # /orders
│       ├── merchant_repository.dart   # /merchants/me*
│       ├── admin_repository.dart      # /admin/*
│       ├── profile_repository.dart    # PATCH /auth/me
│       └── proof_photo_store.dart     # Foto bukti per akun (lokal saja)
└── test/                              # Widget test + unit test
    ├── widget_test.dart               # Smoke: tanpa sesi -> login, mode daftar
    ├── support/fakes.dart             # Sesi & repository palsu untuk widget test
    ├── catalog_screen_test.dart
    ├── booking_screen_test.dart
    ├── booking_to_orders_test.dart     # Alur lengkap booking -> status
    ├── api_integration_test.dart       # P6: API & model (MockClient)
    ├── advanced_features_test.dart     # P7: auth/lokasi/kamera
    ├── p8_ux_test.dart                 # P8: layout/keyboard/a11y/feedback
    ├── p9_refactor_test.dart           # P9: validators/formatters/profile
    ├── p10_bugfix_test.dart            # P10: regresi issue review
    └── orders_persistence_test.dart   # Sesi & foto bukti bertahan
```

## Izin Perangkat (P7)

| Platform | File | Izin |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET` |
| iOS | `ios/Runner/Info.plist` | `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` |

## API yang Dipakai

Base URL diatur saat build: `flutter run --dart-define=API_BASE_URL=http://host:8080`.
Tanpa itu: `10.0.2.2:8080` di emulator Android, `127.0.0.1:8080` di platform lain.

| Method | Endpoint | Dipakai untuk |
|---|---|---|
| `POST` | `/auth/register` | Daftar akun (pembeli / merchant; admin hanya lewat seed) |
| `POST` | `/auth/login` | Login, mengembalikan `{token, user}` |
| `GET` | `/auth/me` | Pulihkan sesi saat aplikasi dibuka |
| `PATCH` | `/auth/me` | Ubah nama & email (role/password ditolak 422) |
| `GET` | `/foods` | Katalog publik (aktif & masih ada kuota) |
| `PUT` | `/merchants/me` | Buat / ubah profil toko |
| `GET` | `/merchants/me/foods` | Semua makanan toko sendiri |
| `GET` | `/merchants/me/stats` | Angka dashboard merchant |
| `POST` | `/foods` | Merchant menambah makanan |
| `PATCH` | `/foods/{id}` | Ubah kuota / detail makanan |
| `POST` | `/orders` | Buat pesanan (harga dihitung server) |
| `GET` | `/orders` | Daftar pesanan sesuai peran |
| `POST` | `/orders/{id}/complete` | Merchant/admin verifikasi kode pick-up |
| `POST` | `/orders/{id}/cancel` | Batalkan, kuota kembali dalam satu transaksi |
| `GET` | `/admin/stats` | Statistik sistem (admin) |
| `GET` | `/admin/users` | Daftar user + filter peran (admin) |

Satu pintu keluar HTTP: `lib/core/network/api_client.dart`. Bentuk error seragam:
`{"error":{"code":"...","message":"..."}}`. Detail internal hanya masuk log server.

Smoke test manual: buka `backend/`, jalankan `dart run tool/seed.dart` lalu
`dart run bin/server.dart`, kemudian login dengan akun demo yang dicetak seed.

## 10. State Management Architecture (Riverpod)

Aplikasi memakai **Riverpod** secara konsisten dengan pemisahan tanggung jawab:

```
UI (Screen)  ──watch──▶  Provider/Notifier  ──read──▶  Repository  ──▶  Data source
     ▲                         │                              │
     └───── rebuild ◀──────────┘                              │
                  AsyncValue<List<SurplusFood>> ◀────────────┘
```

* **Widget (UI):** hanya membaca state via `ref.watch()` dan mengirim aksi via `ref.read()`. Tidak ada logika bisnis di layar.
* **Notifier / Use Case:** memegang state dan logika (misal: `retry()`, `submit()`). Memakai `AsyncNotifier` sehingga state `loading` / `data` / `error` tertangani seragam dalam `AsyncValue`.
* **Repository:** satu-satunya tempat yang tahu dari mana data berasal (backend Dart sendiri; fake dipakai hanya di test). Dibungkus dalam `Provider` supaya bisa di-inject dan di-override saat *testing*.

### Pemetaan 6 Kondisi UI (P4)

| # | Kondisi | Lokasi implementasi |
|---|---------|---------------------|
| 1 | Initial loading | `CatalogNotifier.build()` → `AsyncLoading` → indikator putar di `DashboardScreen` |
| 2 | Data berhasil dimuat | `AsyncData<List<SurplusFood>>` → `FoodCard` di `DashboardScreen` |
| 3 | Empty state | `EmptyStateView` di `DashboardScreen` (kuota habis / pencarian tanpa hasil) |
| 4 | Error state + retry | `ErrorStateView` di `DashboardScreen` + `CatalogNotifier.retry()` |
| 5 | Validasi input pada form | `GlobalKey<FormState>` + validator di `BookingScreen` (nama & jumlah) |
| 6 | Loading saat submit (anti double-tap) | `PrimaryButton(isLoading: true)` → `onPressed: null` saat `BookingNotifier.submit()` |

### Advanced Feature (P7)

| # | Fitur | Repository | Provider | UI | Penanganan izin/batal |
|---|-------|-----------|----------|-----|----------------------|
| 1 | Autentikasi | `auth_repository.dart` | `auth_provider.dart` | `login_screen.dart`, `profile_screen.dart` | error 400 → pesan salah; jaringan → pesan koneksi; logout → dialog konfirmasi |
| 2 | Lokasi | `location_provider.dart` (`GeolocatorLocationRepository`) | `location_provider.dart` | `location_banner.dart` | `denied`, `deniedForever` (+ Settings), `serviceDisabled`; tidak pernah throw |
| 3 | Kamera | `camera_provider.dart` (`ImagePickerCameraRepository`) | `camera_provider.dart` | `pickup_proof_dialog.dart` | `cancelled` = normal; izin ditolak → pesan error; Konfirmasi butuh foto |

Repository lokasi & kamera mengembalikan objek hasil (`LocationResult`, `CameraResult`),
bukan melempar exception, sehingga penolakan izin tidak membuat aplikasi crash.
Widget test meng-override ketiga repository dengan fake karena plugin butuh platform channel.

## 11. UX Rules (P8)
* **Layout adaptif:** konten dibungkus `ResponsiveBody` (max 480–1100 px);
  grid katalog memakai `SliverGridDelegateWithMaxCrossAxisExtent` sehingga
  kolom menyesuaikan lebar layar tanpa `if`.
* **Keyboard-safe:** setiap layar berform memakai `SingleChildScrollView` +
  `padding.bottom = MediaQuery.viewInsetsOf(context).bottom`, dan field memakai
  `textInputAction` agar navigasi keyboard jelas.
* **Aksesibilitas:** tombol ikon memakai `IconButton`/`InkWell` (ripple,
  tooltip, target sentuh ≥ 48 px); field memakai `Semantics(label: ...)`;
  card makanan punya satu label ringkas untuk screen reader.
* **Feedback aksi:** semua aksi memberi respons — snackbar (`AppFeedback`),
  dialog konfirmasi untuk aksi destruktif, spinner + tombol disabled untuk
  proses async. Tidak ada handler kosong (`onTap: () {}`).

## 12. Runtime Logging (P10)

Log terpusat di `lib/core/utils/app_log.dart` memakai `dart:developer` (tanpa
package tambahan), sehingga muncul di console `flutter run`, DevTools, dan
`adb logcat -s flutter` pada build release.

| Titik | Yang dicatat |
|---|---|
| `AppLog.info` | start aplikasi, `METHOD endpoint`, status HTTP sukses |
| `AppLog.warn` | respons non-2xx beserta status code |
| `AppLog.error` | gagal jaringan, body bukan JSON, error tak tertangani |
| `FlutterError.onError` | error build/layout widget |
| `PlatformDispatcher.instance.onError` | error platform di build release |
| `runZonedGuarded` | error async di luar zona Flutter |
| `AppRouteLogger` | `push` / `pop` / `replace` antar halaman |

## 13. Penyimpanan Pesanan (P10)

Pesanan disimpan per akun, bukan per perangkat:

```dart
OrderLocalRepositoryImpl.keyFor(int? userId)
// null   -> 'food_rescue_orders_guest'
// 1      -> 'food_rescue_orders_u1'
```

- `orderLocalRepositoryProvider` dan `OrdersNotifier.build()` sama-sama
  `watch(currentUserProvider)`, jadi logout/login memuat ulang riwayat akun
  yang baru.
- Data versi lama di key global `food_rescue_orders` dimigrasikan sekali ke
  akun yang sedang login, lalu key lama dihapus.
- Bukti pengambilan (`Order.proofPhoto`) disimpan sebagai base64 di storage
  yang sama — tidak butuh `path_provider` atau file system.

## 14. Deliverables
* Source code Flutter yang bisa dijalankan (`flutter run`).
* Widget test untuk setiap state utama (`flutter test` — 84 test lulus).
* Dokumentasi P4, P6 (`docs/P6_API_INTEGRATION.md`), P7 (`docs/P7_MVP_ADVANCED.md`),
  P8 (`docs/P8_UX_RESPONSIVE.md`), P9 (`docs/P9_REFACTOR.md`), P10
  (`docs/P10_BUGFIX.md`, `docs/P10_ISSUES_SPACE_SYNC.md`) + screenshot di
  `docs/screenshots/`.
* Runtime logging (`AppLog`) yang aktif di debug maupun release.
* README dengan instruksi instalasi dan menjalankan aplikasi.
