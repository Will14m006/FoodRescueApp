# Backend — Sesi 4: Akun Admin, Seed CLI, Dashboard

Sesi ini menutup celah terakhir di sisi peran: **bagaimana admin ada** dan
**bagaimana merchant mengelola stoknya tanpa katalog publik**.

## Yang dibuat

```
backend/tool/seed.dart                    # admin + data demo, idempoten
backend/lib/routes/admin_routes.dart      # /admin/users, /admin/stats
backend/lib/middleware/pagination.dart    # ?limit=&offset= bersama
backend/lib/routes/merchant_routes.dart   # + /merchants/me/foods & /stats
```

## Endpoint

| Method | Path | Akses | Keterangan |
|---|---|---|---|
| GET | `/admin/users?role=&limit=&offset=` | admin | daftar user tanpa `passwordHash` |
| GET | `/admin/stats` | admin | angka ringkas seluruh sistem |
| GET | `/merchants/me/foods?limit=&offset=` | merchant | **semua** makanan, termasuk nonaktif/habis |
| GET | `/merchants/me/stats` | merchant | penjualan toko sendiri |

### `/admin/stats`

```json
{
  "users":  { "total": 3, "buyer": 1, "merchant": 1, "admin": 1 },
  "merchants": { "total": 1 },
  "foods":  { "active": 3, "remainingQuota": 15 },
  "orders": { "total": 1, "pending": 0, "completed": 1,
              "cancelled": 0, "revenue": 6000 },
  "generatedAt": "2026-11-26T03:47:45.107685Z"
}
```

`revenue` = `SUM(totalPrice) WHERE status != 'cancelled'`. Uang dari pesanan
yang dibatalkan bukan pendapatan.

### `/merchants/me/foods` vs `GET /foods`

| | `GET /foods` (publik) | `GET /merchants/me/foods` |
|---|---|---|
| Nonaktif | tidak tampil | tampil |
| Kuota 0 | tidak tampil | tampil |
| Milik toko lain | tampil (katalog) | tidak tampil |
| Butuh token | tidak | merchant |

Merchant butuh melihat makanan yang **sudah habis** — kalau hanya memakai
katalog publik, makanan yang kuotanya 0 menghilang dari dashboardnya sendiri
dan tidak bisa diisi ulang.

## Seed CLI (bukan endpoint)

```powershell
cd backend
$env:SEED_PASSWORD = 'AdminKuat123'          # lebih aman dari --password
dart run tool/seed.dart --email admin@foodrescue.id --name "Admin Food Rescue"
```

Keluaran:

```
Admin dibuat: admin@foodrescue.id
Data demo dibuat untuk toko "Warung Bu Siti".
  pembeli   : buyer@foodrescue.id / DemoFood123
  merchant  : toko@foodrescue.id / DemoFood123
Selesai. Database: data/food_rescue.db
```

| # | Keputusan | Alternatif yang ditolak | Kenapa |
|---|---|---|---|
| 1 | Admin **hanya** lewat CLI di mesin server | endpoint `POST /admin/promote` | Endpoint promosi = siapa pun yang menemukannya bisa menjadi admin. Hak istimewa tertinggi tidak boleh bisa dicapai lewat jaringan |
| 2 | Password dibaca dari `SEED_PASSWORD` / prompt tanpa gema | `--password` sebagai satu-satunya cara | Argumen CLI terlihat di riwayat shell dan daftar proses (`ps`) |
| 3 | Seed **idempoten**: email sudah ada → role dinaikkan + password diganti | gagal dengan "sudah ada" | Skenario nyata: lupa password admin. Jalankan ulang, selesai |
| 4 | Data demo dilewati kalau makanan sudah ada | selalu menyisipkan | Menjalankan seed 10× tidak boleh menghasilkan 30 makanan duplikat |
| 5 | Role dari argumen **divalidasi** (`isValidEmail`, panjang password) | percaya begitu saja | Salah ketik email menghasilkan akun yang tidak bisa login dan membingungkan |
| 6 | Tidak ada endpoint untuk **mengubah role** siapa pun | `PATCH /admin/users/<id>/role` | Satu-satunya jalur naik-peran adalah CLI. Test memastikan `/admin/users/1/role`, `/users/1/role`, `/admin/role` semuanya 404 |
| 7 | `GET /admin/users` memakai `userJson` yang sama dengan auth | mapper terpisah | Satu definisi = tidak ada endpoint yang "lupa" membuang `passwordHash` |
| 8 | Paginasi menolak `limit=0`, `limit>200`, `offset<0` dengan 422 | diam-diam pakai default | Klien yang salah harus tahu, bukan diberi halaman yang bukan permintaannya |
| 9 | Statistik dihitung dengan `COUNT`/`SUM` di SQL | tarik semua baris lalu hitung di Dart | Tetap murah saat data bertambah; `remainingQuota` tidak perlu memuat setiap makanan |

## Perbaikan yang ikut masuk

**1. Peringatan drift di test.**

```
WARNING (drift): It looks like you've created the database class AppDatabase
multiple times. When these two databases use the same QueryExecutor, race
conditions will occur and might corrupt the database.
```

Peringatan ini untuk kasus *executor yang sama*, sedangkan setiap `TestApi`
memakai `NativeDatabase.memory()` sendiri. Dimatikan lewat
`driftRuntimeOptions.dontWarnAboutMultipleDatabases = true` di
`test/support.dart` — bukan dengan mengabaikan peringatan yang mungkin benar.

**2. Bug di test saya sendiri.** Test "database kosong" memakai `api` dari
`setUp` alih-alih `fresh`, sehingga mengharapkan 1 user padahal ada 3. Ditemukan
karena test gagal dengan `Expected: <1> Actual: <3>` — bukan karena kode
produksi salah.

## Bukti yang dijalankan

```
dart analyze  -> No issues found!
dart test     -> 126 / 126 lulus
```

Tambahan dari sesi 3: `admin_test.dart` (21 test).

Uji manual terhadap server sungguhan dengan data hasil seed:

| Uji | Hasil |
|---|---|
| `dart run tool/seed.dart` | admin + 3 makanan demo dibuat |
| seed dijalankan ulang | "sudah ada (3 makanan), dilewati" — idempoten |
| `GET /admin/stats` | users 3 (1/1/1), foods 3, quota 15 |
| `GET /admin/users?limit=2` | 2 user, **tanpa** `passwordHash` |
| buyer → `/admin/stats` | **403** |
| merchant → `/merchants/me/foods` | 3 (semua, termasuk kuota 1) |
| pesan Roti (kuota 1) → complete | 201 → `completed`, revenue 6000 |
| `GET /admin/stats` setelah transaksi | `completed: 1, revenue: 6000, remainingQuota: 14` |
| `/merchants/me/stats` | `portionsSold: 1, revenue: 6000` — konsisten |
| respons `/orders` | ada `buyerName`, **tanpa** email |
| log server | 0 `[ERROR]`, 0 stack, 0 password, 0 token, 0 pickupCode, 0 email |

## Yang sengaja belum dibuat

| Belum | Alasan / kapan |
|---|---|
| Endpoint ubah/ hapus user oleh admin | Belum ada kebutuhan; menghapus user akan memutus pesanan lamanya |
| Statistik per hari / grafik tren | Butuh `GROUP BY date(created_at)`; baru berguna dengan data berbulan-bulan |
| Ekspor CSV | Fitur laporan, bukan inti PBL |
| Notifikasi (email/push) | Butuh layanan eksternal |
| Rate limiting global | Di reverse proxy saat deploy |

## Langkah sesi 5

Integrasi Flutter: ganti `dummyjson` dengan backend ini.
`ApiClient` diarahkan ke `http://10.0.2.2:8080` (emulator Android),
`auth_repository` memakai `/auth/login`, `roleProvider` membaca klaim role,
katalog dari `GET /foods`, pesanan dari `POST /orders`, dan dashboard merchant
memakai `/merchants/me/stats`. Token disimpan lewat `shared_preferences` dan
dikirim sebagai `Authorization: Bearer`.
