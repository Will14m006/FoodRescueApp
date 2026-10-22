# Architecture: Food Rescue App

## 1. Purpose
Membantu restoran atau kafe (Mitra) menjual makanan surplus layak konsumsi di akhir jam operasional kepada pengguna (Pembeli) dengan harga diskon. Aplikasi ini mengelola ketersediaan stok secara *real-time* dan menggunakan sistem validasi kode *pick-up* untuk pengambilan di tempat.

## 2. Tech Stack
* **Frontend (Mobile):** Flutter (Dart)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Backend & Web Admin:** Laravel (PHP) terintegrasi dengan RESTful API (direncanakan, belum diimplementasi pada fase ini)
* **Database Pusat:** MySQL (direncanakan)
* **Penyimpanan Lokal (Mobile):** SharedPreferences
* **Advanced Features (P7):** Autentikasi (HTTP), Lokasi (`geolocator`), Kamera (`image_picker`)
* **Environment:** Android Studio & Android SDK, VS Code, Flutter SDK

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
   * Login ke API `POST https://dummyjson.com/auth/login` (akun demo `emilys` / `emilyspass`).
   * Menampilkan state loading, error (password salah / jaringan), dan sukses.
   * Data user (nama, email) dipakai di halaman profil; logout dengan dialog konfirmasi.
2. **Lokasi / GPS** (advanced feature)
   * Banner lokasi di dashboard: koordinat titik jemput, tombol aktifkan & perbarui.
   * Menangani izin: `granted`, `denied`, `deniedForever` (buka Settings), `serviceDisabled`.
   * Repository tidak pernah melempar exception — semua kondisi jadi `LocationResult`.
3. **Kamera** (advanced feature)
   * Foto bukti pengambilan saat menandai pesanan "Sudah Pickup".
   * User membatalkan kamera = kondisi normal (`cancelled`), bukan error.
   * Tombol Konfirmasi non-aktif sampai foto ada.
4. **Katalog Surplus (Buyer Feed)**
   * Menampilkan daftar `SurplusFood` yang aktif dan masih memiliki kuota.
   * **Data diambil dari API** (`GET /products/category/groceries`) melalui
     repository + model, lengkap dengan state loading / empty / error / retry.
   * Pencarian makanan berdasarkan nama atau nama toko.
5. **Booking / Pemesanan**
   * Form pemesanan dengan validasi input (nama, jumlah pesanan).
   * **Pesanan dikirim ke backend** (`POST /carts/add`); kode *pick-up*
     diturunkan dari ID yang dikembalikan server (contoh: `RESCUE-209`).
   * Tombol pesan *disabled* saat proses submit untuk mencegah double-tap.
6. **Orders Screen (Status & Riwayat Pesanan)**
   * Status Pesanan: lihat status + aksi "Sudah Pickup" (dengan bukti foto kamera) / "Batalkan". Pesanan tidak bisa dihapus user (never hard-delete).
   * Riwayat Pesanan: read-only, data diambil dari local storage.
   * Semua data disimpan lokal di perangkat (SharedPreferences / localStorage)
     dan tetap tersedia setelah aplikasi ditutup & dibuka lagi.
7. **Validasi Pesanan (Mitra)**
   * Fitur bagi mitra untuk memvalidasi kode unik saat pelanggan mengambil makanan (direncanakan).
8. **Order Status rules:**
   * `PENDING`: Order created, waiting for pickup.
   * `COMPLETED`: Food picked up and code validated.
   * `CANCELLED`: Order cancelled by buyer or merchant.

## 7. Mobile Screens

1. **Login Screen**
   * Input username & password + validasi, state loading/error, pindah ke dashboard saat sukses.
2. **Dashboard Screen (Katalog Surplus / Buyer Feed)**
   * Banner lokasi (advanced feature GPS) di atas search bar.
   * Daftar makanan surplus dalam bentuk card.
   * Setiap card memiliki informasi: toko, menu, harga asli (coret), harga diskon, sisa kuota, dan tombol "Pesan".
3. **Booking Screen (Pemesanan)**
   * Rincian makanan yang dipilih.
   * Form detail pemesanan (nama, jumlah, catatan) dengan validasi.
4. **Orders Screen (Riwayat Pesanan)**
   * Daftar pesanan yang disimpan di local storage, **read-only**.
5. **Order Status Screen (Status Pesanan)**
   * Daftar pesanan + aksi Update (Sudah Pickup / Batalkan). Tidak ada aksi hapus.
   * "Sudah Pickup" membuka dialog bukti foto kamera (advanced feature).
6. **Profile Screen**
   * Nama & email user asli dari API login + tombol Keluar (dialog konfirmasi).

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
│   │   └── theme/
│   │       ├── app_colors.dart
│   │       ├── app_spacing.dart
│   │       ├── app_text_styles.dart
│   │       └── app_theme.dart
│   ├── routes/                        # Definisi named routes
│   │   └── app_routes.dart
│   ├── screens/                       # Lapisan UI (widget)
│   │   ├── login_screen.dart
│   │   ├── dashboard_screen.dart      # Fitur 1: Katalog Surplus
│   │   ├── booking_screen.dart        # Fitur 2: Booking / Pemesanan
│   │   ├── order_status_screen.dart   # P5: Status Pesanan (aksi Update)
│   │   ├── orders_screen.dart         # P5: Riwayat Pesanan (read-only)
│   │   └── profile_screen.dart
│   ├── widgets/                       # Reusable component
│   │   ├── primary_button.dart
│   │   ├── app_text_field.dart
│   │   ├── food_card.dart
│   │   ├── food_card_skeleton.dart
│   │   ├── empty_state_view.dart
│   │   ├── error_state_view.dart
│   │   ├── location_banner.dart       # P7: UI lokasi (advanced #2)
│   │   └── pickup_proof_dialog.dart   # P7: UI kamera (advanced #3)
│   ├── models/                        # Model data
│   │   ├── surplus_food_model.dart
│   │   └── order_model.dart
│   ├── providers/                     # State management (Riverpod notifier)
│   │   ├── auth_provider.dart         # P7: auth state (advanced #1)
│   │   ├── location_provider.dart     # P7: lokasi + izin (advanced #2)
│   │   ├── camera_provider.dart       # P7: kamera + batal (advanced #3)
│   │   ├── catalog_provider.dart
│   │   ├── booking_provider.dart
│   │   └── orders_provider.dart       # P5: CRUD riwayat pesanan
│   └── repositories/                  # Sumber data (API + local storage)
│       ├── auth_repository.dart         # P7: ApiAuthRepository (POST login)
│       ├── surplus_food_repository.dart # P6: ApiSurplusFoodRepository (GET)
│       ├── order_repository.dart       # P6: ApiOrderRepository (POST)
│       └── order_local_repository.dart # P5: localStorage/SharedPreferences
└── test/                              # Widget test + unit test
    ├── widget_test.dart
    ├── catalog_screen_test.dart
    ├── booking_screen_test.dart
    ├── booking_to_orders_test.dart     # P5: integration test alur lengkap
    ├── api_integration_test.dart       # P6: 15 unit test API & model
    ├── advanced_features_test.dart     # P7: 10 test auth/lokasi/kamera
    └── orders_persistence_test.dart   # P5: persistence test
```

## Izin Perangkat (P7)

| Platform | File | Izin |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET` |
| iOS | `ios/Runner/Info.plist` | `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` |

## API yang Dipakai

| Method | Endpoint | Dipakai untuk |
|---|---|---|
| `GET` | `https://dummyjson.com/products/category/groceries?limit=100` | Memuat katalog surplus |
| `POST` | `https://dummyjson.com/carts/add` | Menyimpan pesanan ke backend |
| `POST` | `https://dummyjson.com/auth/login` | Login user (advanced feature #1) |

Semua endpoint mendukung CORS sehingga aman dipanggil dari Flutter web.
Smoke test manual: `dart run tool/api_smoke.dart`, `dart run tool/p7_smoke.dart`.

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
* **Repository:** satu-satunya tempat yang tahu dari mana data berasal (saat ini *fake* / di-mock, nanti diganti REST API ke backend Laravel). Dibungkus dalam `Provider` supaya bisa di-inject dan di-override saat *testing*.

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

## 11. Deliverables
* Source code Flutter yang bisa dijalankan (`flutter run`).
* Widget test untuk setiap state utama (`flutter test` — 52 test lulus).
* Dokumentasi P4, P6 (`docs/P6_API_INTEGRATION.md`), P7 (`docs/P7_MVP_ADVANCED.md`).
* README dengan instruksi instalasi dan menjalankan aplikasi.
