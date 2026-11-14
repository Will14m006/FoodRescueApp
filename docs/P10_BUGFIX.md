# P10: Runtime Logging, APK, & Bug Fix dari Review

> Instruksi: "Log system ketika program sudah running (agar bisa membantu tracing
> masalah saat on running mode) · menyiapkan apk file · atau yang lebih bagus
> adalah membuat online di playstore. Pembuatan Issues / Bug di github/JIRA
> minimal 10 issues (minimal 5 bug found, selebihnya bisa nambah fitur)."

P10 adalah **peer review dua arah**:

1. Reviewer (`celineemercy`) membuka 5 issue di repo kita → kita verifikasi,
   perbaiki, dan buktikan dengan test regresi.
2. Kita mereview aplikasi reviewer (`celineemercy/space-sync`) → kita laporkan
   minimal 10 issue (≥5 bug) di repo-nya.

## Ringkasan hasil

| Item | Hasil |
|---|---|
| Issue dari reviewer | 5 (semua **valid**, semua diperbaiki) |
| Test regresi baru | 14 (`test/p10_bugfix_test.dart`) |
| Total test | **84 lulus**, `flutter analyze` bersih |
| Logging runtime | `AppLog` (`dart:developer`) + global error handler + route logger |
| Issue yang kita laporkan ke `space-sync` | 12 (7 bug, 5 fitur) — lihat `docs/P10_ISSUES_SPACE_SYNC.md` |
| APK | **belum** — Android SDK tidak terpasang di mesin ini (lihat §5) |

## 1 — Verifikasi 5 issue dari reviewer

Semua issue dicek ke kode sebelum diperbaiki. Tidak ada yang ditolak.

| # | Judul issue | Titik bug di kode lama | Valid? |
|---|---|---|---|
| 1 | Riwayat pesanan dibagi antar akun | `order_local_repository.dart:26` — satu key global `food_rescue_orders`; `logout()` hanya reset memory | ✅ |
| 2 | Layar sukses muncul sebelum pesanan tersimpan | `booking_screen.dart:247` — `addOrder(order)` tanpa `await`, sheet langsung tampil | ✅ |
| 3 | Foto bukti pengambilan dibuang | `pickup_proof_dialog.dart:128` — `clear()` lalu `pop(true)`; `Order` tidak punya field foto | ✅ |
| 4 | `userId: 1` hard-code di request | `order_repository.dart` — body `'userId': 1` | ✅ |
| 5 | Kuota & jam ambil tidak mencerminkan ketersediaan | `surplus_food_model.dart:138` — `1 + stock % ceiling`; `_pickupWindowFor(id % 4)` | ✅ |

## 2 — Perbaikan

### #1 Riwayat per akun

`lib/repositories/order_local_repository.dart`

```dart
static String keyFor(int? userId) =>
    userId == null ? 'food_rescue_orders_guest' : 'food_rescue_orders_u$userId';
```

- `OrderLocalRepositoryImpl({this.userId})` → key storage ikut akun.
- `orderLocalRepositoryProvider` **watch** `currentUserProvider`, dan
  `OrdersNotifier.build()` juga watch → logout/login otomatis memuat ulang.
- Data lama di key global `food_rescue_orders` dimigrasikan sekali ke akun yang
  sedang login (`_migrateLegacy`), jadi riwayat pengguna lama tidak hilang.

### #2 Simpan dulu, baru tampil sukses

`lib/screens/booking_screen.dart` — `ref.listen` dihapus, alur dipindah ke
`_submit()` yang di-`await` berurutan:

```
submit() → cek error → await addOrder() → reduceQuota() → _showSuccessSheet()
```

Kalau penyimpanan lokal gagal, snackbar error tampil dan layar sukses **tidak**
muncul.

### #3 Foto bukti disimpan

- `Order.proofPhoto` (`String?`, base64) + `copyWith` + JSON back-compat.
- `PickupProofDialog` mengembalikan `Uint8List` foto, bukan `true`.
- `order_status_screen.dart` meng-encode base64 lalu `markCompleted(id,
  proofPhoto: ...)`. Gagal simpan → status tidak berubah.
- `order_card.dart` menampilkan thumbnail `_ProofThumb` supaya bukti bisa
  diperiksa lagi kapan saja.

Base64 dipilih supaya tidak perlu `path_provider` / file system — cukup satu
field di storage yang sudah ada.

### #4 `userId` dari sesi

- `OrderRepository.createOrder(..., required int userId)`.
- `BookingNotifier.submit` membaca `currentUserProvider`; kalau belum login →
  `BookingException('Kamu harus login dulu untuk memesan.')`.
- Body POST memakai `userId` asli, bukan literal `1`.

### #5 Kuota dari stok nyata

- `SurplusFood.quota = stock` apa adanya (0 kalau stok ≤ 0).
- `quotaCeiling` / `_quotaFor` (modulo) dihapus.
- `CatalogNotifier.reduceQuota(foodId, qty)` dipanggil setelah booking sukses,
  jadi angka "sisa porsi" tidak beku lagi.
- `pickupWindow` tetap turunan id produk karena dummyjson tidak punya jam
  operasional merchant — tapi di UI sekarang dilabeli **"Estimasi ambil pukul
  …"**, bukan diklaim sebagai jadwal asli.

## 3 — Test regresi

`test/p10_bugfix_test.dart` — 14 test, dikelompokkan per nomor issue. Setiap
test **gagal** pada kode sebelum perbaikan.

| Grup | Test |
|---|---|
| #1 | key per akun berbeda · pesanan A tidak terlihat B · logout→login memuat ulang · migrasi key lama |
| #2 | `addOrder` menulis storage sebelum state berubah |
| #3 | `proofPhoto` bertahan setelah JSON round-trip · `markCompleted` menyimpannya · data lama tanpa foto tetap terbaca |
| #4 | body POST memakai `userId` yang dikirim · dua user → dua id · booking tanpa login ditolak |
| #5 | `quota == stock` · `reduceQuota` mengurangi katalog · kuota tidak negatif |

```
flutter test     -> 00:16 +84: All tests passed!
flutter analyze  -> No issues found!
```

## 4 — Logging runtime

Tidak menambah package. `dart:developer` sudah bawaan Dart.

`lib/core/utils/app_log.dart`

```dart
AppLog.info('...');            // level 800
AppLog.warn('...', error);     // level 900
AppLog.error('...', e, stack); // level 1000
```

`lib/main.dart`

- `runZonedGuarded` — error async di luar Flutter tetap tercatat.
- `FlutterError.onError` — error build/layout.
- `PlatformDispatcher.instance.onError` — error platform (release).
- `AppRouteLogger` (`NavigatorObserver`) — mencatat `push` / `pop` / `replace`,
  jadi urutan layar bisa direkonstruksi saat tracing bug.

`lib/core/network/api_client.dart` — setiap request mencatat
`METHOD endpoint`, status HTTP, dan penyebab gagal (jaringan / non-JSON / JSON
bukan object).

Cara membaca log:

```bash
flutter run            # console + DevTools
adb logcat -s flutter  # build release di perangkat
```

## 5 — APK & Play Store: status

**Belum bisa dikerjakan di mesin ini.** `flutter doctor`:

```
[✗] Android toolchain - develop for Android devices
    ✗ Unable to locate Android SDK.
```

Tidak ada SDK di `%LOCALAPPDATA%\Android\Sdk`, `C:\Android`, `ANDROID_HOME`,
maupun `ANDROID_SDK_ROOT`. Java 23 ada, tapi `flutter build apk` tetap butuh
SDK + build-tools.

Play Store juga belum feasible: belum ada akun developer, dan
`android/app/build.gradle.kts` masih memakai debug signing +
`applicationId = "com.example.food_rescue_app"` (wajib unik & ditandatangani
release key).

**Rencana yang disarankan** — pakai GitHub Actions, tidak perlu SDK lokal:

1. `.github/workflows/build-apk.yml` sudah ditambahkan: `flutter analyze` +
   `flutter test` + `flutter build apk --release` di `ubuntu-latest`, lalu APK
   diunggah sebagai artifact. Jalankan lewat tab **Actions → Build APK → Run
   workflow**, atau push tag `v*`.
2. `applicationId` sudah diganti jadi `id.ac.pradita.foodrescue`.
3. `android/app/build.gradle.kts` sekarang membaca `android/key.properties`
   (tidak di-commit) dan memakai `signingConfigs.release` kalau file itu ada;
   tanpa file tersebut build tetap jalan dengan debug key.
4. Play Store menyusul setelah akun developer tersedia: buat keystore,
   isi 4 GitHub Secrets (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`,
   `STORE_PASSWORD`), lalu `flutter build appbundle` dan unggah AAB ke Play
   Console.

## 6 — Issue untuk aplikasi reviewer

Aplikasi reviewer: `celineemercy/space-sync` (React Native/Expo + NestJS,
branch `dev`). Hasil review ada di
[`docs/P10_ISSUES_SPACE_SYNC.md`](./P10_ISSUES_SPACE_SYNC.md) — 12 issue
(7 bug, 5 fitur) siap dipaste ke GitHub Issues.

## 7 — File yang berubah

| File | Perubahan |
|---|---|
| `lib/models/order_model.dart` | `proofPhoto`, `userId`, `copyWith`, JSON back-compat |
| `lib/models/surplus_food_model.dart` | `quota = stock`, hapus `quotaCeiling`/`_quotaFor`, `copyWithQuota` |
| `lib/repositories/order_local_repository.dart` | key per akun + migrasi data lama + simpan bukti |
| `lib/repositories/order_repository.dart` | `userId` wajib |
| `lib/providers/orders_provider.dart` | watch user aktif, `markCompleted(proofPhoto:)` |
| `lib/providers/booking_provider.dart` | wajib login, teruskan `userId` |
| `lib/providers/catalog_provider.dart` | `reduceQuota` |
| `lib/screens/booking_screen.dart` | alur simpan→sukses, update kuota |
| `lib/screens/order_status_screen.dart` | simpan bukti base64 |
| `lib/widgets/pickup_proof_dialog.dart` | kembalikan bytes foto |
| `lib/widgets/order_card.dart` | `_ProofThumb` |
| `lib/core/utils/app_log.dart` | **baru** — logging terpusat |
| `lib/main.dart` | `runZonedGuarded` + error handler + route logger |
| `lib/core/network/api_client.dart` | log request/status/error |
| `test/p10_bugfix_test.dart` | **baru** — 14 test regresi |
