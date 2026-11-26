# Backend — Sesi 2: Autentikasi JWT + Role Guard

Sesi ini menambahkan identitas ke API: siapa yang memanggil, dan boleh apa.
Tiga endpoint (`/auth/register`, `/auth/login`, `/auth/me`) plus satu middleware
`authGuard` yang akan dipakai seluruh sesi berikutnya.

## Yang dibuat

```
backend/lib/auth/
├── jwt_service.dart      # terbitkan + verifikasi token HS256
├── password_hasher.dart  # bcrypt + dummy hash anti user-enumeration
├── auth_middleware.dart  # authGuard(roles: …) + authenticatedUser()
└── login_throttle.dart   # batas percobaan login per email+IP

backend/lib/middleware/access_log.dart   # log 1 baris, tanpa stack trace
backend/lib/routes/auth_routes.dart      # 3 endpoint + validasi
backend/test/{auth,jwt_service,access_log}_test.dart + support.dart
```

## Endpoint

| Method | Path | Body | Sukses | Gagal |
|---|---|---|---|---|
| POST | `/auth/register` | `email`, `password`, `name`, `role?` | 201 + token + user | 409 email, 422 validasi, 403 role admin, 413/415/400 |
| POST | `/auth/login` | `email`, `password` | 200 + token + user | 401 identik, 429 terlalu banyak |
| GET | `/auth/me` | — (Bearer) | 200 + user | 401 |

Respons sukses selalu `{token, tokenType:"Bearer", expiresIn, user}`.
`user` = `{id, email, name, role, createdAt}`. **`passwordHash` tidak pernah
keluar** di endpoint mana pun.

```powershell
$r = curl.exe -s -X POST http://127.0.0.1:8080/auth/register `
  -H "Content-Type: application/json" `
  -d '{\"email\":\"budi@example.com\",\"password\":\"PasswordKuat123\",\"name\":\"Budi\"}'
# {"token":"eyJhbGciOiJIUzI1NiIs…","tokenType":"Bearer","expiresIn":3600,
#  "user":{"id":1,"email":"budi@example.com","name":"Budi","role":"buyer",…}}
```

## Keputusan keamanan (dan alasannya)

| # | Keputusan | Alternatif yang ditolak | Kenapa |
|---|---|---|---|
| 1 | **Admin tidak bisa didaftarkan lewat HTTP** (403) | menerima `role` apa adanya | Siapa pun yang menemukan endpoint register langsung jadi admin. Admin dibuat lewat seed CLI di sesi 4 |
| 2 | **401 seragam** untuk "tanpa token", "tanda tangan salah", "kedaluwarsa" | pesan berbeda per kasus | Membedakannya = memberi penyerang peta jalan. Klien hanya perlu tahu "login ulang" |
| 3 | Login gagal untuk email tak terdaftar & password salah memakai **pesan identik** | "email tidak ditemukan" | Mencegah enumerasi email |
| 4 | **bcrypt tetap dijalankan** walau email tidak ada (dummy hash) | `return 401` lebih awal | Tanpa ini, email terdaftar terdeteksi dari waktu respons (≈0 ms vs ≈350 ms) |
| 5 | **Throttle 5 percobaan / 15 menit per (email + IP)** → 429 | tanpa batas | bcrypt memperlambat *satu* tebakan, bukan *jumlah* tebakan. Kunci per email+IP supaya orang lain tidak bisa mengunci akun kita |
| 6 | Password **> 72 byte ditolak**, bukan dipotong | potong diam-diam | bcrypt hanya membaca 72 byte; memotong membuat user mengira seluruh passwordnya berlaku |
| 7 | Panjang password dihitung **per byte UTF-8** | per karakter | `🔐` = 4 byte; 30 emoji sudah 120 byte |
| 8 | **`BCRYPT_COST` divalidasi 10..15**, server menolak start di luar itu | terima angka apa pun | Cost 8 = hash cepat dipecahkan; cost 16 = login >1 detik dan mudah jadi DoS |
| 9 | Token wajib punya **`exp`**, `sub` berupa angka, `role` dikenal, `alg` **harus HS256** | verifikasi tanda tangan saja | Tanpa kunci algoritma, token HS512 dengan secret sama juga diterima. `dart_jsonwebtoken` memilih algoritma dari header token — persis celah `alg:none` bila tidak dikunci |
| 10 | `iss = food-rescue-api` diverifikasi | tanpa issuer | Token dari aplikasi lain yang kebetulan memakai secret sama tidak diterima |
| 11 | Body request dibatasi **8 KB** (content-length *dan* ukuran nyata) | tanpa batas | Satu request `chunked` bisa menghabiskan memori. `content-length` bisa bohong, jadi dicek dua kali |
| 12 | `Content-Type` wajib `application/json` (415) | parsing apa pun | Mencegah request lintas-origin sederhana (form) menyentuh API |
| 13 | Rute ber-token mengembalikan **`www-authenticate: Bearer`** | hanya 401 kosong | Sinyal standar HTTP untuk klien |
| 14 | `role` token **tidak** dipercaya untuk data sensitif; `/auth/me` membaca ulang user dari DB | pakai klaim saja | User yang dihapus / role yang diubah langsung berlaku |

## Kenapa `logRequests()` bawaan shelf dibuang

Saat uji manual, log server penuh stack trace untuk kejadian normal:

```
[ERROR] POST /auth/login
ApiException(401, invalid_credentials): Email atau password salah.
package:food_rescue_backend/routes/auth_routes.dart 49:18
… 8 baris lagi
```

`logRequests()` mencetak stack untuk **setiap** exception, termasuk 4xx yang
memang disengaja. Diganti `accessLog`:

```
[2026-11-26T03:21:52.276066Z] POST   401 /auth/login 353ms
```

Satu baris per request, memuat method, status akhir, path, dan durasi.
**Tidak** mencatat query string (bisa memuat token), header, atau body.

Penempatan middleware juga dikoreksi:

```
SecurityHeaders → accessLog → errorHandler → router
```

`SecurityHeaders` paling luar supaya respons 500 buatan `errorHandler` tetap
berheader keamanan; `accessLog` di luar `errorHandler` supaya yang dicatat
status akhir, bukan exception mentah.

## Header respons (diperiksa lewat `curl -i`)

```
HTTP/1.1 200 OK
permissions-policy: geolocation=(), microphone=(), camera=()
referrer-policy: no-referrer
content-type: application/json; charset=utf-8
x-frame-options: DENY
x-xss-protection: 0
x-content-type-options: nosniff
```

Dua temuan saat verifikasi:

1. `x-powered-by` **tidak bisa** dihapus dari dalam handler — `dart:io`
   menambahkannya setelah handler selesai. Cara benar: `shelf_io.serve(...,
   poweredByHeader: null)`. Sudah dipakai di `lib/app.dart`.
2. `dart:io HttpServer` sendiri memasang `x-frame-options: SAMEORIGIN` dan
   `x-xss-protection: 1; mode=block` secara default. Middleware kita
   menimpanya menjadi `DENY` dan `0` (nilai yang direkomendasikan OWASP;
   `1; mode=block` sudah usang dan bisa menimbulkan masalah di browser modern).

## Bukti yang dijalankan

```
dart analyze          -> No issues found!
dart test             -> 62 / 62 lulus
```

Uji manual terhadap server sungguhan (`dart run bin/server.dart`):

| Uji | Hasil |
|---|---|
| register merchant | `201`, role `merchant`, token 3 bagian |
| login | `200`, token berbeda dari register (iat baru) |
| `/auth/me` tanpa token | `401` + `www-authenticate: Bearer` |
| `/auth/me` dengan token | `200`, data user |
| register `role=admin` | `403`, tabel `users` tetap kosong |
| 6× login password salah | `401`×5 lalu `429` |
| token dipalsukan (role diganti) | `401` (tanda tangan tidak cocok) |
| password di DB | `$2a$12$…` panjang 60, bukan teks asli |
| log server | 0 `[ERROR]`, 0 stack trace, 0 password, 0 token, 0 hash |

## Test yang mengunci keamanan (62 total)

`auth_test.dart` (34) — bagian terpenting:

- password disimpan `$2a$…`, **tidak** memuat teks asli
- `passwordHash` tidak muncul di respons register/`me`
- email dinormalisasi lowercase; `Budi@X.com` bentrok dengan `budi@x.com`
- `role=admin` → 403 **dan** tabel users tetap kosong
- password 73 byte → 422; 72 byte → 201; 30 emoji → 422
- body 9 KB → 413; `text/plain` → 415; array JSON → 400
- login email-tak-ada vs password-salah → **pesan identik**
- 5 gagal → 429; login sukses mereset hitungan
- token buyer di rute merchant → **403**; tanpa token → **401** (bukan 403)
- token buyer dengan `role` diubah → 401
- **password/token tidak pernah muncul di log**, hash tidak di respons

`jwt_service_test.dart` (10): token sah, secret lain, kedaluwarsa, string
sampah, tanpa `role`, role tak dikenal, `sub` bukan angka, `exp` wajib ada.

`access_log_test.dart` (3): satu baris per request, query string tidak
dicatat, exception tidak mencetak stack.

`config_test.dart` (9) + `health_test.dart` (6): aturan sesi 1 tetap dijaga,
ditambah penolakan `BCRYPT_COST` di luar 10..15.

## Yang sengaja belum dibuat

| Belum | Alasan / kapan |
|---|---|
| Refresh token | TTL 60 menit cukup; tambahkan bila sesi mobile perlu > beberapa jam |
| Blacklist/revoke token | Butuh penyimpanan bersama; baru relevan setelah multi-instance |
| Rate limit global per IP | Throttle login sudah menutup jalur paling sensitif; limit umum di reverse proxy |
| Seed akun admin | **Sesi 4**, lewat CLI |
| Reset password / verifikasi email | Butuh layanan email; di luar cakupan PBL |
| HTTPS | Diterminasi reverse proxy saat deploy |

## Langkah sesi 3

`/foods` (CRUD merchant, katalog publik buyer) + `/orders` dengan **kuota yang
dikurangi secara transaksional** — dua buyer terakhir tidak boleh sama-sama
berhasil memesan unit terakhir. Test: kuota 1 dipesan 2 request paralel → satu
201, satu 409.
