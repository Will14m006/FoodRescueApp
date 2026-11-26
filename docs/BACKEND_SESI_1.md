# Backend — Sesi 1: Fondasi & Keamanan

Fondasi REST API Food Rescue dengan Dart. Sesi ini **hanya** menyiapkan kerangka,
konfigurasi, dan model database — belum ada endpoint auth/katalog/pesanan.
Tujuannya: server bisa dijalankan, menolak konfigurasi tidak aman, dan seluruh
respons sudah lewat satu jalur middleware yang konsisten.

## Stack & alasan

| Komponen | Paket | Alasan |
|---|---|---|
| HTTP | `shelf` 1.4 + `shelf_router` | Resmi Dart team. **Tanpa codegen** router, jadi tidak ada langkah `build_runner` tambahan yang bisa gagal saat demo |
| ORM | `drift` 2.x + `NativeDatabase` | Type-safe, migration bawaan, dan **sama** dengan yang dipakai Flutter nanti. Pindah SQLite→MySQL cukup ganti executor |
| DB | SQLite (WAL) | Nol server, nol Docker (Docker Desktop tidak menyala di mesin dev). Sampai ±10⁴ baris cukup |
| Password | `bcrypt` | Hash + salt otomatis. Disiapkan untuk sesi 2 |
| Token | `dart_jsonwebtoken` | JWT HS256, siap untuk claim `role` di sesi 2 |
| Config | `dotenv` | Hanya membaca `.env` lokal |

`dart_frog` sengaja tidak dipakai: butuh `build_runner` untuk generate router,
sehingga satu error generator menghentikan seluruh project.

## Struktur

```
backend/
├── .env                    # RAHASIA — di-ignore git
├── .env.example            # template, aman di-commit
├── bin/server.dart         # entry point: baca config, bind, graceful shutdown
├── lib/
│   ├── app.dart            # pipeline middleware + serve()
│   ├── config.dart         # AppConfig.load() + validate()
│   ├── db/database.dart    # tabel Drift + migration
│   ├── middleware/
│   │   ├── api_response.dart    # bentuk JSON seragam + errorHandler
│   │   └── security_headers.dart
│   └── routes/router.dart  # /health + fallback 404 JSON
├── test/
│   ├── config_test.dart    # 7 test: penolakan secret tidak aman
│   └── health_test.dart    # 6 test: /health, 404, kebocoran 500
└── tool/gen_secret.dart    # generator JWT_SECRET
```

## Menjalankan

```powershell
cd food_rescue_app/backend
dart pub get
dart run build_runner build --delete-conflicting-outputs   # generate database.g.dart
Copy-Item .env.example .env
dart run tool/gen_secret.dart        # cetak secret 64 karakter, tempel ke .env
dart run bin/server.dart
```

Verifikasi:

```powershell
curl.exe -s -i http://127.0.0.1:8080/health
```

```http
HTTP/1.1 200 OK
content-type: application/json; charset=utf-8
x-content-type-options: nosniff
x-frame-options: DENY
referrer-policy: no-referrer
x-powered-by:

{"status":"ok","service":"food-rescue-backend","time":"...",""}
```

## Keputusan keamanan (dan alasannya)

| # | Keputusan | Alternatif yang ditolak | Kenapa |
|---|---|---|---|
| 1 | **Server menolak start** kalau `JWT_SECRET` kosong, < 32 karakter, atau masih placeholder | memberi default `"secret"` | Secret default = siapa pun bisa memalsukan token admin. Gagal start lebih baik daripada berjalan tidak aman |
| 2 | `.env`, `*.sqlite`, `*.pem`, `*.jks`, `key.properties` di-ignore di **root `.gitignore`** | per-folder saja | Root mencakup `backend/` maupun `food_rescue_app/android/`, jadi tidak ada celah bila ada subfolder baru |
| 3 | `.env.example` di-**un-ignore** eksplisit (`!.env.example`) | — | Template tetap bisa dibagikan tanpa pernah memuat nilai nyata |
| 4 | `AppConfig.describe()` dan `toString()` mencetak `jwtSecret=<dijaga>` | mencetak objek config apa adanya | Satu `print(config)` tidak boleh membocorkan kunci |
| 5 | **Bind default `127.0.0.1`** | `0.0.0.0` | Server lokal tidak terbuka ke Wi-Fi kampus/cafe. Dibuka sadar via `--host 0.0.0.0` |
| 6 | Semua exception → **500 JSON generik**; stack trace hanya ke log server | membiarkan `shelf` mengirim halaman HTML berisi stack | Stack trace membocorkan path, versi paket, dan struktur kode |
| 7 | Header `x-content-type-options: nosniff`, `x-frame-options: DENY`, `referrer-policy: no-referrer` di **semua** respons, termasuk 404 & 500 | hanya di respons sukses | Respons error justru yang paling sering diabaikan |
| 8 | `x-powered-by` dikosongkan | — | Fingerprint `Dart with package:shelf` memudahkan penyerang memilih exploit |
| 9 | `PRAGMA foreign_keys = ON` + `journal_mode = WAL` + `busy_timeout` | default SQLite | SQLite **mematikan FK** secara default — tanpa ini, `references()` hanya dekorasi. WAL mencegah `database is locked` saat baca & tulis bersamaan |
| 10 | 404 selalu JSON | halaman bawaan shelf | Klien Flutter tidak perlu dua jalur parsing |
| 11 | Hard-delete dipakai nanti untuk katalog, sedangkan order **tidak boleh** dihapus (aturan `Architecture.md` §5) | — | Disiapkan lewat kolom `isActive` sejak skema |

## Skema database (v1)

```
Users        id, email(unique), passwordHash, name, role, createdAt
Merchants    id, storeName, ownerId → Users, createdAt        (unique ownerId)
SurplusFoods id, merchantId → Merchants, name, description,
             originalPrice, discountPrice, quota, pickupWindow, isActive, createdAt
Orders       id, buyerId → Users, foodId → SurplusFoods,
             quantity, totalPrice, pickupCode(unique), status, createdAt
```

Dibuat lengkap sekarang (bukan hanya `Users`) supaya `schemaVersion` tetap 1 dan
sesi 2–4 tidak perlu migrasi tabel baru. Belum ada endpoint yang menyentuhnya.

## Bukti yang sudah dijalankan

```
dart analyze          -> No issues found!
dart test             -> 13 / 13 lulus
```

Uji manual yang sudah lolos:

1. **Tanpa `.env`** → server menolak:
   `KONFIGURASI GAGAL: JWT_SECRET belum diisi...` (exit 78)
2. **`.env` masih placeholder** → server menolak:
   `JWT_SECRET masih berisi nilai contoh dari .env.example...`
3. **`.env` berisi secret 64 karakter** → server jalan, log menampilkan
   `jwtSecret=<dijaga>`
4. **`curl /health`** → `200` + 3 header keamanan + `x-powered-by` kosong
5. **`curl /tidak-ada`** → `404` JSON `{"error":{"code":"not_found",...}}`
6. **Akses lewat LAN IP** (`172.24.112.1:8080`) → ditolak, karena bind loopback
7. **`git check-ignore backend/.env`** → cocok, `.env` tidak akan pernah ter-commit

## Test yang mengunci keamanan

`test/config_test.dart` (7):
- menerima secret sah
- menolak kosong / placeholder / < 32 karakter
- menolak `DATABASE_FILE` kosong
- `describe()` dan `toString()` tidak memuat secret

`test/health_test.dart` (6):
- `/health` → 200 + field `status`/`service`/`time`
- 3 header keamanan ada
- `content-type` JSON + `utf-8`
- rute tak dikenal → 404 JSON (bukan HTML)
- 404 tetap berheader keamanan
- **exception → 500 dengan pesan generik**, detail internal hanya masuk log

Test terakhir itu yang paling penting: kalau suatu saat ada handler yang lupa
menangani error, data pribadi tidak ikut keluar ke klien.

## Yang sengaja belum dibuat

| Belum | Alasan / kapan |
|---|---|
| TLS/HTTPS | Diterminasi di reverse proxy saat deploy; localhost tidak butuh |
| Rate limiting | Baru relevan setelah server terbuka ke internet |
| JWT service & middleware | **Sesi 2** |
| Endpoint `/auth/*`, `/foods`, `/orders` | Sesi 2–4 |
| Docker | SQLite file cukup; Dockerfile ditambah saat deploy |
| Refresh token | Hanya bila TTL diperpanjang > beberapa jam |

## Langkah sesi 2

`lib/auth/jwt_service.dart` + `lib/auth/auth_middleware.dart` +
`lib/routes/auth_routes.dart`, dengan test yang membuktikan:
token tanpa `role` ditolak, token `buyer` tidak bisa membuka rute merchant,
dan password **tidak pernah** muncul di log.
