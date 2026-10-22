# P6: Integrasi API & Vertical Slice

> "Hubungkan UI dengan API melalui repository dan model (Penyimpanan data ke
> Backend dan Loading dari Backend). Tampilkan loading, empty, error, success,
> serta retry."

## 1. Fitur Inti yang Dipilih

**Katalog Surplus (Buyer Feed)** — fitur inti yang sudah ada sejak P1/P4,
sekarang datanya benar-benar diambil dari API sungguhan.

Vertical slice yang sudah utuh:

```
UI (dashboard_screen.dart)
   ↓ ref.watch(catalogProvider)
State (catalog_provider.dart / CatalogNotifier)
   ↓ ref.read(surplusFoodRepositoryProvider)
Repository (surplus_food_repository.dart)
   ↓ http.get(...)
API  https://dummyjson.com/products/category/groceries
   ↓ jsonDecode
Model (surplus_food_model.dart / SurplusFood.fromJson)
```

Untuk penyimpanan ke backend, alur Booking juga sudah tersambung:

```
UI (booking_screen.dart)
   ↓ bookingProvider.submit(...)
State (booking_provider.dart / BookingNotifier)
   ↓ orderRepositoryProvider
Repository (order_repository.dart)
   ↓ http.post(...)
API  https://dummyjson.com/carts/add
```

## 2. Posisi Code

| Bagian | File | Keterangan |
|---|---|---|
| **API — baca katalog** | `lib/repositories/surplus_food_repository.dart` → `ApiSurplusFoodRepository` | `GET /products/category/groceries` |
| **API — simpan pesanan** | `lib/repositories/order_repository.dart` → `ApiOrderRepository` | `POST /carts/add` |
| **Model + validasi** | `lib/models/surplus_food_model.dart` → `SurplusFood.fromJson` | Melempar `InvalidModelException` kalau JSON tidak valid |
| **Error type** | `lib/repositories/surplus_food_repository.dart` → `ApiException` | Pesan ramah pengguna, bukan stack trace |
| **State** | `lib/providers/catalog_provider.dart`, `booking_provider.dart` | `AsyncNotifier` + `AsyncValue.guard` |
| **UI** | `lib/screens/dashboard_screen.dart`, `booking_screen.dart` | Menampilkan 6 kondisi |

Dependency baru: `http: ^1.2.2` di `pubspec.yaml`.

## 3. Enam Kondisi UI

| Kondisi | Tampilan | Lokasi |
|---|---|---|
| **Loading** | Skeleton shimmer grid | `dashboard_screen.dart` → `_buildSkeletonGrid()` |
| **Empty** | `EmptyStateView` ("Belum Ada Makanan Tersedia") | `dashboard_screen.dart` saat `filtered.isEmpty` |
| **Error** | `ErrorStateView` + pesan dari `ApiException` | `dashboard_screen.dart` cabang `error:` |
| **Retry** | Tombol "Coba Lagi" → `catalogProvider.notifier.retry()` | `error_state_view.dart` |
| **Success** | Grid `FoodCard` berisi data dari API | `dashboard_screen.dart` cabang `data:` |
| **Success (form)** | Bottom sheet kode pick-up dari server | `booking_screen.dart` |

`retry()` mengosongkan state ke `AsyncLoading` lalu memanggil ulang API —
jadi pengguna bisa mencoba lagi tanpa restart aplikasi.

## 4. Penanganan Error Berlapis

| Penyebab | Ditangkap di | Jadi |
|---|---|---|
| Offline / timeout | `catch` di repository | `ApiException('Tidak bisa terhubung ke server...')` |
| HTTP 500 / 400 | cek `statusCode` | `ApiException('Server mengembalikan error 500...')` |
| Body bukan JSON | `try jsonDecode` → `FormatException` | `ApiException('Respons server tidak dapat dibaca...')` |
| Struktur JSON salah | cek `decoded['products'] is List` | `ApiException('Format respons server tidak sesuai.')` |
| Field item tidak valid | `SurplusFood.fromJson` | `InvalidModelException` |

Semua error akhirnya masuk ke `AsyncError` dan ditampilkan lewat
`ErrorStateView` — pengguna tidak pernah melihat stack trace.

## 5. Unit Test — 15 Test di `test/api_integration_test.dart`

Semua memakai `MockClient` dari `package:http/testing.dart`, jadi tidak butuh
internet dan hasilnya deterministik.

| # | Skenario diminta | Test |
|---|---|---|
| 1 | **Model valid** | `model valid: SurplusFood.fromJson memetakan semua field` |
| 2 | **Model invalid** | `title kosong` / `price bukan angka` / `id tidak ada` → `InvalidModelException` |
| 3 | **API sukses** | `200 + products berisi data -> List<SurplusFood>` |
| 4 | **Data kosong** | `products: []` → list kosong, bukan error |
| 5 | **HTTP gagal** | `status 500` dan `koneksi terputus` → `ApiException` |
| 6 | **JSON rusak** | body HTML dan struktur tanpa `products` → `ApiException` |

Tambahan: 3 test untuk POST pesanan (sukses, HTTP 400, JSON rusak).

Jalankan:

```bash
flutter test test/api_integration_test.dart
```

Hasil: **15/15 passed**. Total seluruh project: **38 test passed**.

## 6. Bukti Koneksi ke API Sungguhan

Smoke test manual (bukan mock):

```bash
dart run tool/api_smoke.dart
```

Output:

```
GET katalog  -> 27 item
  🍎 Apple | Rp 27.822 | sisa 8
  🍖 Beef Steak | Rp 187.867 | sisa 86
  🛒 Cat Food | Rp 130.060 | sisa 46
POST pesanan -> ord-209 / RESCUE-209 / Rp 55644
```

Artinya: data katalog benar-benar datang dari server, dan pesanan benar-benar
tercatat di backend (ID `209` berasal dari respons server, lalu dipakai sebagai
kode pick-up).

## 7. Cara Demo ke Reviewer

```bash
flutter run -d chrome
```

1. **Loading** — begitu dashboard terbuka, skeleton shimmer tampil ±1 detik
   (menunggu respons API).
2. **Success** — grid katalog terisi data dari dummyjson (nama, harga, stok).
3. **Empty** — ketik kata kunci ngawur di search (mis. `zzz`) → empty state.
4. **Error + Retry** — matikan Wi-Fi / pakai DevTools → Network → Offline, lalu
   tekan tombol retry. Muncul `ErrorStateView` dengan pesan ramah. Nyalakan
   internet, tekan "Coba Lagi" → data muncul lagi.
5. **Success (POST)** — pilih makanan → isi form → "Pesan Sekarang" → bottom
   sheet menampilkan kode pick-up. Buka DevTools → Network, terlihat request
   `POST https://dummyjson.com/carts/add` dengan status 201.

Untuk membuktikan request API secara visual: DevTools (F12) → tab **Network** →
filter `dummyjson` → akan terlihat `GET products/category/groceries` dan
`POST carts/add`.

## 8. Prompt AI yang Digunakan

* "Hubungkan katalog ke API publik yang mendukung CORS dan POST, lalu buat
  repository + model yang menangani error HTTP dan JSON rusak."
* "Buat 6 unit test: model valid, model invalid, API sukses, data kosong, HTTP
  gagal, JSON rusak — pakai MockClient supaya tidak butuh internet."
* "Kenapa widget test gagal setelah repository diganti ke API asli?" —
  jawabannya: `TestWidgetsFlutterBinding` memblokir HTTP, jadi repository harus
  di-override dengan fake di test.

## 9. Bagian yang Saya Periksa / Perbaiki Sendiri

* Memastikan `http.Client` bisa di-inject lewat constructor, supaya repository
  bisa diuji dengan `MockClient` tanpa mengubah kode produksi.
* Menambahkan `timeout` 12 detik — tanpa ini, request yang menggantung membuat
  state loading tidak pernah selesai.
* Memisahkan `ApiException` (masalah jaringan/server) dari
  `InvalidModelException` (kontrak data), supaya pesan ke pengguna tepat.
* Menambahkan filter `isAvailable` di repository — produk dengan stok 0 tidak
  ikut tampil di katalog.
* Meng-override repository dengan fake di seluruh widget test agar test tetap
  deterministik dan tidak bergantung internet.
