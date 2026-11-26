# Backend + App — Sesi 5: `dummyjson` → Backend Sendiri

Sesi ini mengganti seluruh sumber data palsu di aplikasi Flutter dengan backend
Dart yang sudah dibangun pada sesi 1–4, lalu menambahkan dashboard per peran.

## Perubahan besar

| Sebelum | Sesudah |
|---|---|
| `https://dummyjson.com/*` | `http://<host>:8080/*` (backend sendiri) |
| Login fake `emilys` / `emilyspass` | `/auth/login` + JWT; sesi dipulihkan via `/auth/me` |
| Katalog dari `products/category/groceries` | `GET /foods` (kuota nyata, hanya yang aktif) |
| Pesanan dibuat klien + disimpan lokal | `POST /orders`; **server** menentukan harga & kode pick-up |
| `Order.id` string `ord-209-…` | `int` (primary key server) |
| Status pesanan diubah pembeli | Merchant/admin verifikasi kode pick-up |
| Semua user = pembeli | `HomeScreen` memilih dashboard: buyer / merchant / admin |
| Foto bukti = syarat menyelesaikan pesanan | Foto bukti hanya untuk pembeli, **tidak** mengubah status |
| Edit profil: firstName / lastName | Nama + email saja (`PATCH /auth/me`) |

## Berkas baru di aplikasi

```
lib/core/config/api_config.dart            # base URL (--dart-define / default per platform)
lib/core/network/api_exception.dart        # error dengan statusCode
lib/core/session/session_store.dart        # token + profil ringkas
lib/models/user_role.dart                  # cermin UserRole backend
lib/repositories/merchant_repository.dart  # /merchants/me*
lib/repositories/admin_repository.dart     # /admin/*
lib/repositories/proof_photo_store.dart    # foto bukti per akun (lokal)
lib/providers/merchant_provider.dart
lib/providers/admin_provider.dart
lib/screens/home_screen.dart               # pemilih dashboard per peran
lib/screens/merchant_dashboard_screen.dart
lib/screens/admin_dashboard_screen.dart
test/support/fakes.dart                    # sesi + repository palsu
```

Dihapus: `lib/models/user_model.dart`, `lib/services/auth_service.dart`,
`lib/repositories/order_local_repository.dart`.

## Endpoint tambahan

| Method | Path | Akses | Keterangan |
|---|---|---|---|
| PATCH | `/auth/me` | login | ubah nama & email sendiri; role/password ditolak **422** |

`role` tidak diabaikan diam-diam. Kalau klien mengirim `{"role":"admin"}`
dan server hanya diam, klien akan mengira berhasil. Sekarang dijawab:

```json
{ "error": { "code": "immutable_field",
             "message": "Field tidak bisa diubah dari sini: role." } }
```

## Keputusan

| # | Keputusan | Alternatif yang ditolak | Kenapa |
|---|---|---|---|
| 1 | Satu `ApiClient` sebagai satu-satunya egress HTTP | tiap repository menyusun request sendiri | Satu bentuk error, satu tempat menaruh token, satu batas waktu |
| 2 | Base URL dari `--dart-define=API_BASE_URL` | hard-code alamat | Emulator (`10.0.2.2`), perangkat fisik, dan desktop butuh alamat berbeda tanpa mengubah kode |
| 3 | Yang disimpan hanya **token** | simpan email + password | Password di perangkat = kebocoran yang tidak perlu; token bisa dicabut |
| 4 | Sesi dipulihkan lewat `GET /auth/me` | percaya isi SharedPreferences | Token kedaluwarsa / peran berubah harus ketahuan saat start |
| 5 | Backend mati saat start → pakai sesi cache | langsung logout | "Logout sendiri" karena server belum jalan membingungkan; request berikutnya memberi error jaringan yang jelas |
| 6 | Server = sumber kebenaran pesanan | cache pesanan lokal per akun | Merchant memverifikasi kode; kalau tiap perangkat punya salinan sendiri, statusnya berbeda-beda |
| 7 | Foto bukti tetap lokal per akun (`fr_proof_u<id>`) | unggah ke server | SQLite satu file + foto pelanggan = risiko kebocoran tanpa manfaat; kode pick-up sudah bukti yang diverifikasi |
| 8 | Pembeli **tidak** bisa `complete` | sembunyikan tombol saja | Server menolak 403 — menyembunyikan UI bukan pengaman |
| 9 | Nama pemesan dari akun, bukan input | izinkan ketik nama bebas | Mencegah "mengaku orang lain" saat mengambil makanan |
| 10 | `Order.id` / `SurplusFood.id` bertipe `int` | pertahankan string `ord-209-…` | Server memakai primary key integer; memaksa string hanya menambah parsing |
| 11 | `FoodCategory` diturunkan dari nama | tambah kolom kategori di backend | Backend belum punya kategori; filter ini sekadar alat bantu UI, bukan data bisnis |
| 12 | Hapus `rating` / `sold` | isi angka karangan | Angka palsu lebih buruk daripada tidak ada angka; badge diganti sisa porsi nyata |
| 13 | `usesCleartextTraffic` hanya di `src/debug` | nyalakan di manifest utama | Build release tetap menolak HTTP polos, jadi produksi wajib HTTPS |
| 14 | Daftar akun admin tidak ditawarkan di UI | sembunyikan pilihan admin saja | Backend menolak role admin pada register; UI hanya mengikuti aturan itu |

## Bukti yang dijalankan

```
flutter analyze   -> No issues found!
flutter test      -> 92 / 92 lulus
dart analyze      -> No issues found!   (backend)
dart test         -> 134 / 134 lulus    (backend)
```

Uji manual terhadap server sungguhan (seed, lalu login ketiga peran):

| Uji | Hasil |
|---|---|
| login buyer / merchant / admin | 200, token berbeda, `role` benar |
| `GET /foods` | 3 makanan, `merchantName` = "Warung Bu Siti" |
| `PATCH /auth/me` nama | 200, `name` berubah, `role` tetap `buyer` |
| `PATCH /auth/me` `{"role":"admin"}` | **422** `immutable_field`, data tidak berubah |
| `POST /orders` (foodId 2, qty 1) | 201, `pickupCode` `RESCUE-9EW65MGB`, `totalPrice` 6000 |
| buyer → `/orders/1/complete` | **403** |
| merchant → `/orders/1/complete` | 200, status `completed` |
| `GET /merchants/me/stats` | `portionsSold: 1, revenue: 6000, remainingQuota: 14` |
| `GET /admin/stats` | users 3 (1/1/1), orders 0 sebelum transaksi, lalu konsisten |

## Yang sengaja belum dibuat

| Belum | Alasan / kapan |
|---|---|
| TLS di server | Saat deploy, di belakang reverse proxy (Caddy/Nginx) |
| Rate limiting global | Butuh state bersama; tempatnya di reverse proxy |
| Refresh token | Token 60 menit cukup untuk demo; refresh butuh penyimpanan sesi server |
| Unggah foto bukti | Perlu object storage + moderasi; kode pick-up sudah cukup |
| Endpoint ubah peran oleh admin | Satu-satunya jalur naik-peran tetap CLI, seperti sesi 4 |
| Paginasi di UI | `limit=200` cukup untuk skala PBL; UI perlu desain "muat lagi" yang layak |
| Alur reset password | Butuh email/OTP, layanan eksternal |

## Cara menjalankan

```powershell
cd backend
Copy-Item .env.example .env
dart run tool/gen_secret.dart      # salin hasilnya ke JWT_SECRET di .env
$env:SEED_PASSWORD = 'DemoFood123'
dart run tool/seed.dart
dart run bin/server.dart
```

```powershell
cd food_rescue_app
flutter run                                    # emulator Android -> 10.0.2.2:8080
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080   # perangkat fisik
```

Akun demo: `buyer@foodrescue.id`, `toko@foodrescue.id`, `admin@foodrescue.id`
(password sesuai `SEED_PASSWORD`).
