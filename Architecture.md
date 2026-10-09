# Architecture: Food Rescue App

## 1. Purpose
Membantu restoran atau kafe (Mitra) menjual makanan surplus layak konsumsi di akhir jam operasional kepada pengguna (Pembeli) dengan harga diskon. Aplikasi ini mengelola ketersediaan stok secara *real-time* dan menggunakan sistem validasi kode *pick-up* untuk pengambilan di tempat.

## 2. Tech Stack
* **Frontend (Mobile):** Flutter (Dart)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Backend & Web Admin:** Laravel (PHP) terintegrasi dengan RESTful API (direncanakan, belum diimplementasi pada fase ini)
* **Database Pusat:** MySQL (direncanakan)
* **Penyimpanan Lokal (Mobile):** SQLite / Shared Preferences (direncanakan)
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
   * Halaman login dengan role Mitra / Pembeli (sementara disimulasikan).
2. **Katalog Surplus (Buyer Feed)**
   * Menampilkan daftar `SurplusFood` yang aktif dan masih memiliki kuota.
   * Pencarian makanan berdasarkan nama atau nama toko.
3. **Booking / Pemesanan**
   * Form pemesanan dengan validasi input (nama, jumlah pesanan).
   * Menghasilkan kode *pick-up* unik (contoh: `RESCUE-101`).
   * Tombol pesan *disabled* saat proses submit untuk mencegah double-tap.
4. **Validasi Pesanan (Mitra)**
   * Fitur bagi mitra untuk memvalidasi kode unik saat pelanggan mengambil makanan (direncanakan).
5. **Order Status rules:**
   * `PENDING`: Order created, waiting for pickup.
   * `COMPLETED`: Food picked up and code validated.
   * `CANCELLED`: Order cancelled by buyer or merchant.

## 7. Mobile Screens

1. **Login Screen**
   * Input email & password, tombol menuju dashboard.
2. **Dashboard Screen (Katalog Surplus / Buyer Feed)**
   * Daftar makanan surplus dalam bentuk card.
   * Setiap card memiliki informasi: toko, menu, harga asli (coret), harga diskon, sisa kuota, dan tombol "Pesan".
3. **Booking Screen (Pemesanan)**
   * Rincian makanan yang dipilih.
   * Form detail pemesanan (nama, jumlah, catatan) dengan validasi.
4. **Profile Screen**
   * Halaman profil pembeli / mitra (placeholder).

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
│   │   └── profile_screen.dart
│   ├── widgets/                       # Reusable component
│   │   ├── primary_button.dart
│   │   ├── app_text_field.dart
│   │   ├── food_card.dart
│   │   ├── food_card_skeleton.dart
│   │   ├── empty_state_view.dart
│   │   └── error_state_view.dart
│   ├── models/                        # Model data
│   │   ├── surplus_food_model.dart
│   │   └── order_model.dart
│   ├── providers/                     # State management (Riverpod notifier)
│   │   ├── catalog_provider.dart
│   │   └── booking_provider.dart
│   └── repositories/                  # Sumber data (abstrak + fake impl)
│       ├── surplus_food_repository.dart
│       └── order_repository.dart
└── test/                              # Widget test untuk tiap state utama
    ├── widget_test.dart
    ├── catalog_screen_test.dart
    └── booking_screen_test.dart
```

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

## 11. Deliverables
* Source code Flutter yang bisa dijalankan (`flutter run`).
* Widget test untuk setiap state utama (`flutter test`).
* Dokumentasi P4 beserta screenshot/video singkat.
* README dengan instruksi instalasi dan menjalankan aplikasi.
