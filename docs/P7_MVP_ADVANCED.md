# P7: MVP Lengkap + 3 Advanced Feature

> "Selesaikan seluruh fitur inti MVP: navigasi, form, validasi, dan penyimpanan
> data. Integrasikan minimal 3 advanced feature (Autentikasi, notifikasi,
> kamera, lokasi, dan sensor) yang relevan dan jelaskan manfaatnya bagi
> pengguna. Lengkapi loading, empty, error, serta penanganan izin atau
> pembatalan."

## 1. Alur Utama MVP (end-to-end)

```
Login (API auth)
   ↓
Dashboard Katalog (API GET) + banner lokasi
   ↓
Booking: form + validasi + dialog konfirmasi
   ↓
POST pesanan ke backend → simpan lokal (SharedPreferences)
   ↓
Status Pesanan: Sudah Pickup (kamera) / Batalkan
   ↓
Riwayat Pesanan (read-only, permanen)
   ↓
Profil: data user asli dari API + Logout
```

Semua langkah di atas bisa didemonstrasikan tanpa data palsu di UI.

## 2. Tiga Advanced Feature

### #1 Autentikasi — `POST https://dummyjson.com/auth/login`

| Bagian | File |
|---|---|
| Repository + model | `lib/repositories/auth_repository.dart` (`AuthUser`, `ApiAuthRepository`) |
| State | `lib/providers/auth_provider.dart` |
| UI | `lib/screens/login_screen.dart`, `lib/screens/profile_screen.dart` |

**Manfaat bagi pengguna:** akun membedakan pesanan tiap orang, dan profil
menampilkan nama/email asli dari server. Logout tersedia di halaman profil
(dengan dialog konfirmasi).

**Penanganan kondisi:**

| Kondisi | Perilaku |
|---|---|
| Loading | tombol berubah "Memproses..." + spinner, tidak bisa double-tap |
| Password salah (HTTP 400) | kotak error merah: "Username atau password salah." |
| Jaringan mati | kotak error: "Tidak bisa terhubung ke server..." |
| Sukses | pindah ke dashboard membawa data user |
| Logout | dialog konfirmasi → kembali ke halaman login |

Akun demo: **`emilys` / `emilyspass`**.

### #2 Lokasi (GPS) — `geolocator`

| Bagian | File |
|---|---|
| Repository + state | `lib/providers/location_provider.dart` |
| UI | `lib/widgets/location_banner.dart` (di dashboard) |
| Izin | `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` |

**Manfaat bagi pengguna:** menampilkan koordinat titik jemput terdekat supaya
pembeli tahu jarak ke mitra sebelum memesan.

**Penanganan izin (semua kasus):**

| Kondisi | Enum | UI |
|---|---|---|
| GPS mati | `serviceDisabled` | pesan "GPS belum aktif" + tombol Coba |
| Izin ditolak | `denied` | pesan + tombol Coba (minta ulang) |
| Ditolak permanen | `deniedForever` | pesan + tombol **Pengaturan** (buka app settings) |
| Sukses | `granted` | koordinat + tombol perbarui |
| Idle | `null` | "Aktifkan lokasi..." + tombol Aktifkan |

Repository **tidak pernah melempar exception** — semua kegagalan dikembalikan
sebagai `LocationResult` supaya UI tidak crash saat izin ditolak.

### #3 Kamera — `image_picker`

| Bagian | File |
|---|---|
| Repository + state | `lib/providers/camera_provider.dart` |
| UI | `lib/widgets/pickup_proof_dialog.dart` |
| Trigger | `lib/screens/order_status_screen.dart` (tombol "Sudah Pickup") |

**Manfaat bagi pengguna:** foto makanan sebagai bukti pengambilan, sehingga
sengketa "sudah/belum diambil" bisa diselesaikan.

**Penanganan izin & pembatalan:**

| Kondisi | Perilaku |
|---|---|
| User menutup kamera | `cancelled: true` → "Pengambilan foto dibatalkan." (bukan error) |
| Izin kamera ditolak | pesan error jelas di dalam dialog |
| Foto berhasil | preview foto; tombol **Konfirmasi** baru aktif |
| Tombol Konfirmasi | non-aktif sebelum ada foto (mencegah pickup tanpa bukti) |

## 3. Loading / Empty / Error / Retry

| Layar | Loading | Empty | Error | Retry |
|---|---|---|---|---|
| Login | tombol spinner | — | kotak error merah | tekan Masuk lagi |
| Dashboard | skeleton shimmer | EmptyStateView | ErrorStateView | tombol Coba Lagi |
| Banner lokasi | spinner | idle state | pesan izin | Coba / Pengaturan |
| Booking | tombol spinner | — | pesan di bawah form | submit ulang |
| Dialog kamera | spinner | "Belum ada foto" | pesan izin | Ambil Foto |
| Status Pesanan | spinner | EmptyStateView | EmptyStateView | Coba Lagi |
| Riwayat | spinner | EmptyStateView | EmptyStateView | Coba Lagi |

## 4. Posisi Code (untuk reviewer)

```
lib/
├── models/
│   ├── surplus_food_model.dart
│   └── order_model.dart
├── repositories/
│   ├── auth_repository.dart          ← ADVANCED #1 (API login)
│   ├── surplus_food_repository.dart  ← P6 API katalog
│   ├── order_repository.dart         ← P6 API pesanan
│   └── order_local_repository.dart   ← P5 local storage
├── providers/
│   ├── auth_provider.dart            ← ADVANCED #1 state
│   ├── location_provider.dart        ← ADVANCED #2 (GPS + izin)
│   ├── camera_provider.dart          ← ADVANCED #3 (kamera + batal)
│   ├── catalog_provider.dart
│   ├── booking_provider.dart
│   └── orders_provider.dart
├── widgets/
│   ├── location_banner.dart          ← ADVANCED #2 UI
│   └── pickup_proof_dialog.dart      ← ADVANCED #3 UI
└── screens/
    ├── login_screen.dart             ← ADVANCED #1 UI
    ├── dashboard_screen.dart
    ├── booking_screen.dart
    ├── order_status_screen.dart
    ├── orders_screen.dart
    └── profile_screen.dart           ← user asli + logout
```

## 5. Pengujian

### Unit test advanced feature — `test/advanced_features_test.dart` (10 test)

| Feature | Test |
|---|---|
| Autentikasi | login sukses, password salah, token tidak ada, jaringan mati |
| Lokasi | izin ditolak, GPS mati, ditolak permanen |
| Kamera | user batal, izin ditolak, foto berhasil |

### Total pengujian project

```bash
flutter test
```

Hasil: **52 test lulus** (model, API, persistence, widget, integration, advanced
feature). `flutter analyze` bersih.

### Bukti ke API sungguhan

```bash
dart run tool/p7_smoke.dart
```

```
AUTH sukses  -> Emily Johnson <emily.johnson@x.dummyjson.com>
Token        -> eyJhbGciOiJIUzI1Ni...
AUTH ditolak -> Username atau password salah.
```

## 6. Cara Demo ke Reviewer

```bash
flutter run -d chrome
```

1. **Autentikasi (sukses)** — isi `emilys` / `emilyspass` → Masuk → masuk dashboard.
   Profil menampilkan nama & email asli dari API.
2. **Autentikasi (gagal)** — logout → isi password salah → muncul pesan merah.
3. **Lokasi** — di dashboard, tekan **Aktifkan** → browser minta izin.
   - Klik **Block** → muncul pesan izin ditolak (aplikasi tidak crash).
   - Klik **Allow** → koordinat tampil.
   - Cabut izin lewat ikon 🔒 di address bar → tekan Coba → muncul tombol
     **Pengaturan**.
4. **Kamera** — buat pesanan → Status Pesanan → **Sudah Pickup** → dialog bukti
   → **Ambil Foto**.
   - Tutup kamera tanpa foto → "Pengambilan foto dibatalkan."
   - Ambil foto → preview muncul → **Konfirmasi** aktif → status jadi SELESAI.
5. **Riwayat** — buka Riwayat Pesanan: read-only, tanpa tombol hapus.

> Catatan: di **web**, kamera memakai input file browser (butuh HTTPS atau
> `localhost`). Di **Android/iOS** memakai kamera native.

## 7. Prompt AI yang Digunakan

* "Implementasikan autentikasi ke API dummyjson dengan Riverpod AsyncNotifier,
  tampilkan loading/error, dan simpan data user untuk halaman profil."
* "Buat repository lokasi yang mengembalikan status izin (granted/denied/
  deniedForever/serviceDisabled) tanpa melempar exception, lalu tampilkan di UI."
* "Integrasikan kamera sebagai bukti pickup: dialog dengan preview foto, tombol
  konfirmasi non-aktif sebelum ada foto, dan penanganan user membatalkan kamera."
* "Kenapa widget test gagal setelah menambah plugin lokasi/kamera?" — jawabannya:
  plugin butuh platform channel, jadi repository harus di-override dengan fake.

## 8. Bagian yang Saya Periksa / Perbaiki Sendiri

* Memastikan repository lokasi & kamera **tidak pernah melempar exception** —
  semua kondisi izin dikembalikan sebagai objek hasil, supaya UI tidak crash
  saat user menolak izin.
* Menambahkan dialog konfirmasi pada logout agar tidak keluar karena salah tap.
* Menambahkan izin `CAMERA` dan `ACCESS_FINE_LOCATION` di AndroidManifest serta
  `NSCameraUsageDescription` / `NSLocationWhenInUseUsageDescription` di
  Info.plist — tanpa ini fitur gagal di perangkat asli.
* Memperbaiki `pickup_proof_dialog.dart`: `double.infinity` di dalam AlertDialog
  memicu error layout (`width.isFinite`), diganti lebar tetap 280.
* Menambahkan override fake untuk auth/lokasi/kamera di seluruh widget test
  supaya test tetap deterministik dan tidak meminta izin perangkat.
