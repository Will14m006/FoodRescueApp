# P10 — Issue untuk `cchiciaa/chiscan`

Hasil review aplikasi rekan (Flutter + Riverpod, branch `v1.0_dev` — repo tidak
punya branch `v1.0`, hanya `main` dan `v1.0_dev`).

Total **6 issue baru** (5 bug + 1 enhancement), sudah **live di GitHub**:

| # | Judul | Label |
|---|-------|-------|
| [#11](https://github.com/cchiciaa/chiscan/issues/11) | Release APK cannot reach the network: INTERNET permission missing from main manifest | bug |
| [#12](https://github.com/cchiciaa/chiscan/issues/12) | API base URL is hard-coded to localhost and plain HTTP, so it never works on a real device | bug |
| [#13](https://github.com/cchiciaa/chiscan/issues/13) | Bill sessions are shared between accounts on the same device | bug |
| [#14](https://github.com/cchiciaa/chiscan/issues/14) | Tax, service charge and discount are never collected, so the stored total always equals the subtotal | bug |
| [#15](https://github.com/cchiciaa/chiscan/issues/15) | Participant payment status is hard-coded to PENDING and can never be marked as paid | bug |
| [#16](https://github.com/cchiciaa/chiscan/issues/16) | Add CI for analyze, test and APK build, and remove JVM crash dumps from the repository root | enhancement |

> Catatan: #11 awalnya dibuat sebagai probe koneksi, lalu diisi ulang dengan isi
> issue sungguhan. Token yang tersedia bisa membuat issue, tapi **tidak bisa
> memasang label** di repo orang lain (butuh push access, 403).

---

## BUG 1 (#11) — Release APK tidak punya izin INTERNET

**File:** `apps/mobile/android/app/src/main/AndroidManifest.xml`

**Problem**
`INTERNET` hanya dideklarasikan di `src/debug/AndroidManifest.xml` dan
`src/profile/AndroidManifest.xml`. Gradle hanya menggabungkan manifest debug
untuk build debug/profile, jadi `flutter build apk --release` menghasilkan APK
tanpa izin jaringan.

**Reproduce**
1. `flutter build apk --release`, install di device.
2. Backend hidup di jaringan yang sama, buka aplikasi.
3. Semua panggilan API gagal `SocketException`.

**Expected** Release build punya akses jaringan seperti debug.

**Suggested fix** Tambah `<uses-permission android:name="android.permission.INTERNET"/>`
ke manifest `main`.

---

## BUG 2 (#12) — Base URL hard-coded `localhost` + cleartext HTTP

**File:** `apps/mobile/lib/services/bill_session_api_client.dart`

**Problem**
`baseUrl` default `http://localhost:3000/api`. Di HP, `localhost` adalah HP itu
sendiri, jadi backend tidak pernah terjangkau. Dua masalah lain di file yang
sama:

- Tidak ada timeout — request menggantung selamanya kalau server mati.
- Android 9+ memblokir cleartext HTTP secara default; tidak ada
  `usesCleartextTraffic` maupun `network_security_config`, jadi URL LAN
  (`http://192.168.x.x:3000/api`) juga gagal dengan
  "Cleartext HTTP traffic not permitted".

**Expected** URL bisa dikonfigurasi per build, error terketik jelas, tidak
menggantung.

**Suggested fix** `--dart-define=API_BASE_URL=...`, `.timeout(...)`, dan
network security config khusus debug.

---

## BUG 3 (#13) — Sesi tagihan bocor antar akun

**File:** `apps/mobile/lib/repositories/bill_session_repository.dart`

**Problem**
`LocalBillSessionRepository` memakai key device-wide `chiscan_bill_sessions`.
`BillSession` tidak punya field pemilik. User kedua di HP yang sama (atau
mahasiswa berikutnya di device lab) melihat sesi, peserta, dan nominal user
sebelumnya. `ProfileRepository` berpola sama, jadi seluruh database lokal
praktis global.

**Reproduce** Buat beberapa sesi → logout / ganti akun → dashboard masih
menampilkan sesi lama.

**Expected** Data lokal per-user, dibersihkan saat logout.

**Suggested fix** Namespace key dengan user id (`chiscan_bill_sessions_$userId`)
atau simpan `userId` per record, lalu hapus key saat logout.

---

## BUG 4 (#14) — Pajak, service, diskon tidak pernah bisa diisi

**File:** `apps/mobile/lib/models/bill_session.dart`,
`apps/mobile/lib/screens/create_session_screen.dart`,
`apps/mobile/lib/repositories/bill_session_repository.dart`

**Problem**
Model sudah punya `taxBasisPoints`, `serviceBasisPoints`, `discountAmount`, dan
`calculateShares()` sudah memprorata ketiganya. Tapi:

- Form create session tidak punya input untuk ketiganya.
- `createSession()` dan `updateSession()` menulis `grandTotalAmount` = subtotal
  item mentah.
- `calculatedGrandTotal` tidak pernah dipakai.

Akibatnya struk dengan PB1 atau diskon tidak bisa dimasukkan sama sekali, dan
total tersimpan selalu salah begitu ada pajak.

**Reproduce** Buat sesi dengan item → cek JSON tersimpan → ketiga field selalu 0.

**Expected** Form mengoleksi ketiganya, tersimpan, total = `calculatedGrandTotal`.

---

## BUG 5 (#15) — Status bayar peserta hard-coded `PENDING`

**File:** `apps/mobile/lib/screens/session_detail_screen.dart`,
`apps/mobile/lib/models/bill_session.dart`

**Problem**
`Chip(label: const Text('PENDING'))` konstan. `BillParticipant` hanya punya
`id` dan `name` — tidak ada field status, tidak ada persistensi, tidak ada aksi
ubah. Aplikasi tidak pernah bisa menjawab pertanyaan intinya sendiri: siapa yang
sudah transfer.

**Reproduce** Buka sesi apa pun → baris peserta tidak bisa ditekan, tetap oranye
PENDING setelah restart.

**Expected** `BillParticipant.status` (unpaid/pending/paid) persisten, bisa
diubah dari detail screen, plus ringkasan lunas vs belum.

---

## FEATURE 1 (#16) — CI + bersihkan crash dump JVM

**Problem**
Tidak ada `.github/workflows`, jadi `flutter analyze`, `flutter test`, dan build
APK tidak pernah diverifikasi. Dua crash dump JVM ter-commit di root repo:
`hs_err_pid25984.log` dan `replay_pid25984.log` — artefak build yang membengkakkan
clone dan mengagetkan siapa pun yang membuka tree.

**Expected** Workflow analyze + test + APK artifact, dan `.gitignore` untuk
`*.log` / `hs_err_pid*.log`.

**Suggested fix** `.github/workflows/ci.yml` dengan `subosito/flutter-action` +
`git rm --cached hs_err_pid25984.log replay_pid25984.log`.

---

## Temuan lain (tidak diposting, sudah tercakup issue lama repo)

Issue #1–#10 di repo ini (dibuat owner) sudah mencakup: data demo hard-coded,
total palsu Rp 195.000, alokasi item diabaikan, kamera/GPS palsu, notifikasi
palsu, API-only offline, cast JSON tidak aman, dan analyzer kotor. Tidak
diduplikasi.

Dua hal kecil yang tidak layak jadi issue terpisah:

- `apps/mobile/lib/validators/bill_session_validator.dart` hanya cek non-empty,
  tanpa batas panjang/karakter.
- `apps/mobile/lib/services/app_logger.dart` memanggil
  `SharedPreferences.getInstance()` di setiap penulisan log, dan tidak ada UI
  `readLogs()` sama sekali — log hanya bisa dibaca lewat debugger.
- `apps/mobile/android/app/build.gradle.kts` masih `com.example.chiscan_mobile`
  + debug signing, jadi tidak bisa dipublikasikan ke Play Store.
