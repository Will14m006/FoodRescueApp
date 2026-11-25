# P10 — Issue untuk `memetkm/Aku-Motor`

Hasil review aplikasi rekan (Flutter + Riverpod + Express/Prisma, branch `main`
— repo tidak punya branch `v1.0`, hanya `main`).

Total **6 issue baru** (5 bug + 1 enhancement), sudah **live di GitHub**:

| # | Judul | Label |
|---|-------|-------|
| [#6](https://github.com/memetkm/Aku-Motor/issues/6) | App cannot be built for Flutter Web: api_client depends on dart:io and has no timeout | bug |
| [#7](https://github.com/memetkm/Aku-Motor/issues/7) | Recording a replacement for the same part silently deletes the previous record and drops the photo | bug |
| [#8](https://github.com/memetkm/Aku-Motor/issues/8) | calculateRemainingDays overflows at end of month and reports the wrong due date | bug |
| [#9](https://github.com/memetkm/Aku-Motor/issues/9) | Email and phone validation accept invalid input and passwords are trimmed before comparison | bug |
| [#10](https://github.com/memetkm/Aku-Motor/issues/10) | Backend has no authentication: any client can read and modify every user data | bug |
| [#11](https://github.com/memetkm/Aku-Motor/issues/11) | No CI: Flutter tests, analyzer and the Express/Prisma build are never verified automatically | enhancement |

> Catatan: token yang tersedia bisa membuat issue, tapi **tidak bisa memasang
> label** di repo orang lain (butuh push access, 403). Label di tabel adalah
> label yang seharusnya dipasang.

---

## BUG 1 (#6) — Tidak bisa build Flutter Web: `dart:io` di `api_client`

**File:** `apps/web/lib/core/network/api_client.dart`

**Problem**
`StandardApiClient` mengimplementasikan HTTP dengan `dart:io` (`HttpClient`,
`HttpClientResponse`, `HttpHeaders`). Repo justru mengirim target web
(`apps/web/web/index.html`, `apps/web/index.html`, konfigurasi Vite/Tailwind),
tapi `dart:io` tidak ada di platform web — `flutter build web` gagal dan
`ApiMotorRepository` tidak bisa dipakai di web. Dua cacat lain di file yang sama:
tidak ada timeout sama sekali, dan `HttpClient` tidak pernah di-`close()`, jadi
backend yang mati meninggalkan UI berputar tanpa batas.

**Reproduce** `flutter build web` di `apps/web`, atau matikan API lalu buka
layar mana pun yang memanggilnya.

**Expected** Lapisan jaringan jalan di Android dan web, gagal cepat dengan
`ApiException` saat timeout, dan melepas koneksi.

**Suggested fix** Pindah ke `package:http`, atau conditional import
(io + html), tambah `.timeout(const Duration(seconds: 10))`, dan tutup client
saat dispose.

---

## BUG 2 (#7) — Ganti part kedua kali menghapus riwayat lama + foto hilang

**File:** `apps/web/lib/features/maintenance/data/shared_preferences_maintenance_repository.dart`,
`apps/web/lib/features/camera/data/app_camera_service.dart`

**Problem**
`create()` mencari record dengan `motorId` + `partType` yang sama, lalu
`items[existingIndex] = record`. User yang mengganti oli kedua kali kehilangan
record pertama seluruhnya — tanggal, kilometer, dan catatan hilang dalam satu
tap. Backend `ServiceHistory` justru menyimpan setiap penggantian, jadi perilaku
offline dan online bertentangan.

Dua cacat lain di method yang sama:

- `photoUrl` tidak pernah di-set pada record baru, padahal
  `MaintenanceRecord` punya field tersebut.
- `AppCameraService.takePhoto()` hanya mengembalikan string palsu
  `receipt_photo://...`, bukan path file nyata — jadi foto yang "dilampirkan"
  dibuang dua kali.

**Reproduce** Tambah record Oli Mesin, lalu tambah lagi untuk part sama dengan
tanggal berbeda → hanya yang terbaru tersisa.

**Expected** Setiap penggantian tersimpan sebagai riwayat, referensi foto
persisten, dan kamera mengembalikan path nyata atau diberi label demo.

---

## BUG 3 (#8) — `calculateRemainingDays` overflow akhir bulan

**File:** `apps/web/lib/features/maintenance/domain/maintenance_record.dart`

**Problem**
Due date dihitung `DateTime(y, month + intervalMonth, day)`. Dart menormalkan
hari yang overflow, bukan meng-clamp:

- 31 Januari + 1 bulan → 3 Maret (Februari 2026 hanya 28 hari)
- 31 Maret + 1 bulan → 1 Mei

Sisa hari jadi beberapa hari terlalu longgar, status tetap "Aman" melewati
tanggal jatuh tempo sebenarnya, dan pengingat terlambat. Bug tidak terlihat di
demo karena data contoh memakai tanggal pertengahan bulan.

**Reproduce**
`MaintenanceRecord(lastReplacedAt: DateTime(2026, 1, 31), partType: 'Oli Mesin', ...).calculateRemainingDays(now: DateTime(2026, 3, 1))`
mengembalikan nilai positif padahal seharusnya negatif.

**Expected** Pakai hari terakhir bulan target (28/29 Februari).

**Suggested fix**
```dart
final lastDay = DateTime(y, m + interval + 1, 0).day;
final due = DateTime(y, m + interval, day.clamp(1, lastDay));
```

---

## BUG 4 (#9) — Validasi email/HP lemah + password di-trim

**File:** `apps/web/lib/features/auth/domain/validation.dart`,
`apps/web/lib/features/auth/data/shared_preferences_auth_repository.dart`

**Problem**
`validateEmail` hanya `contains('@') && contains('.')` → `a@b.`, `@.`, dan
`user@@mail.com` lolos. `validatePhone` menerima string non-empty apa pun,
termasuk huruf.

Di repository, `login()` dan `register()` memanggil `password.trim()`:

- `" secret "` dan `"secret"` dianggap password sama.
- Password berisi enam spasi lolos cek minimal 6 karakter.
- User yang kemudian menghapus spasi jadi tidak bisa login.

**Reproduce** Daftar dengan email `a@b.` dan password enam spasi, lalu login
dengan `a@b.` dan password kosong setelah trim.

**Expected** Satu pola email tervalidasi, aturan HP hanya digit dengan panjang
wajar, dan password dibandingkan byte-per-byte tanpa trim.

---

## BUG 5 (#10) — Backend tanpa autentikasi

**File:** `apps/api/src/app.ts`, `apps/api/src/routes/motorRoutes.ts`

**Problem**
Semua router didaftarkan tanpa middleware identitas:

- `GET /api/motors` mengembalikan **seluruh** motor di database tanpa filter
  pemilik.
- `PUT` / `DELETE /api/motors/:Id` (juga part, service-history, usage-profile,
  dashboard) beroperasi pada id numerik mentah.
- `cors()` dipanggil tanpa opsi → semua origin diizinkan.

Sistem akun hanya hidup di SharedPreferences di HP, jadi API berperilaku seperti
satu database publik bersama. Siapa pun yang tahu URL bisa membaca, mengubah,
atau menghapus catatan kendaraan orang lain.

**Reproduce** `curl http://localhost:3000/api/motors` tanpa kredensial apa pun →
semua motor keluar.

**Expected** Request membawa identitas, kepemilikan dicek sebelum baca/tulis,
request tanpa auth dapat 401, CORS dibatasi ke origin aplikasi.

---

## FEATURE 1 (#11) — Tidak ada CI

**Problem**
Tidak ada `.github/workflows`. `apps/web` punya folder `test`, tapi
`flutter analyze` dan `flutter test` hanya dijalankan manual. API Express tidak
pernah di-type-check di CI. `prisma generate` + service MySQL dibutuhkan sebelum
API bisa build, jadi clone bersih gagal dengan cara yang tidak ketahuan sampai
rilis.

**Expected** Dua job: `apps/web` (`flutter pub get`, `analyze`, `test`) dan
`apps/api` (`npm ci`, `npx prisma generate`, `npm run build`) dengan MySQL
service container.

---

## Temuan lain (tidak diposting, sudah tercakup issue lama repo)

Issue #1–#5 di repo ini (dibuat owner) sudah mencakup: GPS palsu di
`workshop_location_service.dart`, password plaintext di
`aku_motor.auth_users.v1`, data antar akun bercampur, booking tidak pernah
sampai ke bengkel, dan pengingat servis tanpa notifikasi device. Tidak
diduplikasi.

Temuan tambahan yang tidak layak jadi issue terpisah:

- `apps/web/lib/features/auth/data/shared_preferences_auth_repository.dart`
  punya akun demo hard-coded `budi@akumotor.id` / `password123` di dalam kode
  produksi.
- `getCurrentUser()` memakai `catch (_) { return null; }` — data sesi rusak
  membuat user ter-logout diam-diam tanpa pesan.
- `apps/web/lib/features/camera/data/app_camera_service.dart` dan
  `workshop_location_service.dart` sama-sama mengganti izin OS nyata dengan flag
  SharedPreferences (`requestPermission()` selalu `granted` tanpa pernah
  bertanya ke OS).
- `apps/web/android/app/src/main/AndroidManifest.xml` tidak punya izin
  `INTERNET` maupun `ACCESS_FINE_LOCATION` di manifest main — build release
  akan kehilangan jaringan, masalah sama dengan `chiscan#11`.
- `apps/web/android/app/build.gradle.kts`: `signingConfig = debug`, tidak bisa
  publish ke Play Store.
