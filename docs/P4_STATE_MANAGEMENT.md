# P4: State Management Documentation

> "Terapkanlah 2 fitur untuk mengimplementasikan state management."
>
> Feature wajib memiliki minimal enam kondisi UI: initial loading, data berhasil dimuat, empty state, error state dengan tombol retry, validasi input pada form, serta loading saat proses submit agar pengguna tidak dapat melakukan double tap.

## 1. Dua Fitur yang Diimplementasikan

| # | Fitur | File utama |
|---|-------|------------|
| 1 | **Katalog Surplus (Buyer Feed)** — menampilkan daftar makanan surplus dari berbagai mitra, dengan pencarian. | `lib/screens/dashboard_screen.dart` |
| 2 | **Booking / Pemesanan** — memesan makanan surplus dan mendapatkan kode pick-up unik (misal: `RESCUE-101`). | `lib/screens/booking_screen.dart` |

Kedua fitur memakai **Riverpod (`flutter_riverpod`)** sebagai state management, dipakai secara konsisten di seluruh aplikasi.

## 2. Posisi Code State Management

Pemisahan tanggung jawab mengikuti aturan: **widget**, **notifier/use case**, dan **repository**.

```
lib/
├── core/                         ← DESIGN SYSTEM (tema, warna, tipografi)
│   └── theme/
│       ├── app_colors.dart
│       ├── app_spacing.dart
│       ├── app_text_styles.dart
│       └── app_theme.dart
├── providers/                     ← STATE MANAGEMENT (notifier / use case)
│   ├── catalog_provider.dart      ← Fitur 1: Katalog Surplus
│   └── booking_provider.dart      ← Fitur 2: Booking / Pemesanan
├── repositories/                  ← SUMBER DATA
│   ├── surplus_food_repository.dart
│   └── order_repository.dart
├── screens/                       ← WIDGET (UI, baca state saja)
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── booking_screen.dart
│   └── profile_screen.dart
├── widgets/                       ← REUSABLE COMPONENT
│   ├── food_card.dart
│   ├── food_card_skeleton.dart
│   ├── empty_state_view.dart
│   ├── error_state_view.dart
│   ├── primary_button.dart
│   └── app_text_field.dart
└── models/                        ← MODEL DATA
    ├── surplus_food_model.dart
    └── order_model.dart
```

Desain UI mengikuti Material 3 dengan font "Plus Jakarta Sans", palet warna
terpusat di `core/theme/`, dan layout adaptif (grid 1 kolom di mobile,
2+ kolom di desktop).

### a. Notifier (Use Case) — `lib/providers/catalog_provider.dart`

```dart
class CatalogNotifier extends AsyncNotifier<List<SurplusFood>> {
  @override
  Future<List<SurplusFood>> build() async => _fetch();

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<SurplusFood>> _fetch() {
    return ref.read(surplusFoodRepositoryProvider).fetchSurplusFoods();
  }
}

final catalogProvider =
    AsyncNotifierProvider<CatalogNotifier, List<SurplusFood>>(CatalogNotifier.new);
```

Memakai `AsyncNotifier` sehingga tiga state async (`loading` / `data` / `error`) tertangani seragam oleh `AsyncValue`. Layar hanya memanggil `ref.watch(catalogProvider)` dan `ref.read(catalogProvider.notifier).retry()`.

### b. Notifier (Use Case) — `lib/providers/booking_provider.dart`

```dart
class BookingNotifier extends AsyncNotifier<Order?> {
  @override
  Order? build() => null;

  Future<void> submit({...}) async {
    state = const AsyncLoading<Order?>();
    state = await AsyncValue.guard(() {
      return ref.read(orderRepositoryProvider).createOrder(...);
    });
  }

  void reset() {
    state = const AsyncData<Order?>(null);
  }
}
```

### c. Repository — `lib/repositories/`

Repository adalah satu-satunya tempat yang tahu dari mana data berasal. Saat ini memakai **fake implementation** yang mengsimulasikan panggilan API (delay + kegagalan jaringan):

```dart
@override
Future<List<SurplusFood>> fetchSurplusFoods() async {
  await Future.delayed(delay);

  if (simulateFailureOnFirstCall && !_hasFailedOnce) {
    _hasFailedOnce = true;
    throw Exception('Gagal memuat katalog. Periksa koneksi internet kamu.');
  }
  ...
}
```

Kontraknya berupa `abstract class`, sehingga saat backend Laravel siap, cukup dibuat implementasi lain tanpa mengubah UI maupun notifier. Saat *testing*, repository di-override via `surplusFoodRepositoryProvider.overrideWithValue(...)`.

## 3. Proses: Pemetaan 6 Kondisi UI

| # | Kondisi UI yang wajib | Cara memicu di aplikasi | Lokasi code |
|---|------------------------|--------------------------|-------------|
| 1 | **Initial loading** | Buka aplikasi → login → dashboard. Skeleton shimmer muncul ~1.2 detik (bukan spinner biasa). | `CatalogNotifier.build()` → `AsyncLoading` |
| 2 | **Data berhasil dimuat** | Setelah loading selesai, grid 6 makanan tampil (grid adaptif: 1 kolom di mobile, 2+ di desktop). | `AsyncData` → `FoodCard` di `dashboard_screen.dart` |
| 3 | **Empty state** | Ketik kata kunci yang tidak ada (misal "sate") di kotak pencarian, atau pilih kategori yang kosong. | `EmptyStateView` di `dashboard_screen.dart` |
| 4 | **Error state + tombol retry** | Karena `simulateFailureOnFirstCall = true`, pemanggilan pertama selalu gagal → layar error dengan tombol **Coba Lagi**. Klik retry → data muncul. | `ErrorStateView` + `CatalogNotifier.retry()` |
| 5 | **Validasi input pada form** | Di Booking, kosongkan nama / isi jumlah melebihi kuota → pesan error muncul di field. | `_validateName` & `_validateQuantity` di `booking_screen.dart` |
| 6 | **Loading saat submit (anti double-tap)** | Tekan "Pesan Sekarang" → tombol berubah jadi spinner & *disabled* (`onPressed: null`) selama ~1.5 detik. | `PrimaryButton(isLoading: ...)` + `BookingNotifier.submit()` |

### Alur Fitur 2 (Booking)

```
[Katalog] tap "Pesan"
   ↓ (arguments: SurplusFood)
[BookingScreen]
   ↓ validasi form (GlobalKey<FormState>)
   ↓ lolos → ref.read(bookingProvider.notifier).submit(...)
   ↓ state = AsyncLoading  →  tombol disabled (double-tap dicegah)
   ↓ repository.createOrder() (~1.5 detik)
   ↓ state = AsyncData(Order)
   ↓ ref.listen menangkap → bottom sheet "Pesanan Berhasil! 🎉" + kode RESCUE-101
   ↓ tap "Kembali ke Katalog" → reset state
```

## 4. Widget Test untuk Setiap State Utama

Jalankan dengan:

```bash
cd food_rescue_app
flutter test
```

| Test file | Kondisi yang diuji |
|-----------|--------------------|
| `test/widget_test.dart` | Aplikasi ter-build, halaman login tampil |
| `test/catalog_screen_test.dart` | initial loading, data dimuat, empty state (pencarian), empty state (kuota habis), error + retry |
| `test/booking_screen_test.dart` | validasi nama kosong, validasi nama <3 char, validasi jumlah > kuota, loading saat submit (tombol non-aktif), sukses + kode pick-up |

Total **12 test**, semuanya lulus. Repository di-override di tiap test supaya deterministik (delay singkat & kegagalan terkontrol).

## 5. Cara Mencoba Semua State

1. **Initial loading + error + retry:** `flutter run` → login → tunggu error muncul → tekan "Coba Lagi".
2. **Data dimuat:** daftar 5 makanan muncul setelah retry.
3. **Empty state:** ketik "sate" di kotak pencarian → tekan "Hapus Filter" untuk kembali.
4. **Validasi form + loading submit:** tap "Pesan" di salah satu card → tekan "Pesan Sekarang" dengan field kosong → isi dengan benar → tekan lagi → lihat kode pick-up.

## 6. Prompt AI yang Digunakan

* "Buatkan struktur proyek Flutter sesuai Architecture.md dengan folder `screens`, `widgets`, `models`, `services`, dan `routes`." (P3)
* "Implementasikan 2 fitur dengan Riverpod: katalog makanan surplus dengan state loading/data/empty/error+retry, dan form booking dengan validasi serta loading saat submit."
* "Buatkan widget test untuk setiap state utama dari kedua fitur tersebut."
* "Tulis ulang Architecture.md agar full Flutter dan konsisten dengan implementasi."

## 7. Bagian yang Saya Periksa / Perbaiki Sendiri

* Memperbaiki `test/widget_test.dart` bawaan Flutter yang masih merujuk ke class `MyApp` (seharusnya `FoodRescueApp`) sehingga `flutter analyze` dan `flutter test` gagal.
* Mengubah `PrimaryButton` agar menerima parameter `isLoading`: saat `true`, `onPressed` di-set `null` — mekanisme Flutter bawaan yang menjamin tap kedua tidak memicu apa pun (anti double-tap), bukan sekadar mengabaikan secara manual.
* Menulis ulang `Architecture.md` dari stack React/Node menjadi Flutter agar sesuai dengan kode yang ada.
* Mengonsolidasikan logika validasi (nama minimal 3 karakter, jumlah maksimal sama dengan kuota) di dalam `BookingScreen` dan memverifikasinya lewat test.
* Mengatur ulang test loading agar memakai `pump()` alih-alih `pumpAndSettle()`, karena `pumpAndSettle()` memajukan waktu hingga selesai sehingga state loading terlewat.
