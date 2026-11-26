# Sesi 6 — Fitur Admin Lengkap, Ubah Password, Tangguhkan Akun

Lanjutan sesi 5. Sesi ini menutup 5 issue reviewer dan menambah fitur yang
sebelumnya hanya setengah ada.

## 1. Issue reviewer (GitHub #1–#5) — sudah beres di sesi 5

Kelima issue ditulis terhadap versi lama (`dummyjson` + `SharedPreferences`).
Semuanya sudah diperbaiki di commit `0a049ef`; sesi ini memverifikasi ulang
lalu menambahkan penjelasan dan menutup issue.

| # | Masalah | Perbaikan |
|---|---------|-----------|
| 1 | Riwayat pesanan dibagi antar-akun | Pesanan dari server (`GET /orders`), filter `buyerId`; foto bukti per akun (`fr_proof_u<id>`) |
| 2 | Sukses ditampilkan sebelum tersimpan | `await` server dulu; sheet hanya muncul kalau `201` |
| 3 | Foto bukti dibuang | Dialog mengembalikan `Uint8List`; disimpan `ProofPhotoStore`, tampil di kartu |
| 4 | `userId: 1` hardcode | Identitas dari klaim JWT; server menolak non-buyer |
| 5 | Kuota/jam ambil sintetis | `quota` & `pickupWindow` dari tabel merchant; potong kuota atomik |

## 2. Fitur baru sesi ini

### Backend (schema v2)

| Endpoint | Fungsi |
|----------|--------|
| `PATCH /admin/users/<id>` | Tangguhkan / aktifkan akun (`isActive`) |
| `GET /admin/users/<id>` | Detail user + jumlah pesanan & total belanja |
| `GET /admin/foods` | Semua makanan lintas toko (filter `?active=`) |
| `GET /admin/orders` | Semua pesanan (filter `?status=`) |
| `GET /admin/users?q=` | Cari user berdasarkan nama/email |
| `POST /auth/change-password` | Ubah password (wajib password lama) |

Tambahan pada `GET /admin/stats`: `users.suspended`, `orders.portionsSaved`.

### Aturan penangguhan akun

- Login dengan akun ditangguhkan → **403 `account_suspended`**, dicek **setelah**
  verifikasi password supaya penyerang tidak bisa memetakan akun mana yang
  ditangguhkan tanpa tahu passwordnya.
- Token lama langsung tidak berlaku: `/auth/me` menolak dengan 403.
- Admin **tidak bisa** menangguhkan dirinya sendiri (`409 self_suspend`) —
  satu-satunya jalan keluar adalah seed CLI di mesin server.
- Baris tidak dihapus: pesanan lama harus tetap menunjuk pembeli yang sah.
- Peran **tidak** bisa diubah lewat API. Hanya `isActive`. Menaikkan peran
  lewat API berarti siapa pun yang mencuri token admin bisa mencetak admin baru.

### Migrasi database v1 → v2

```sql
ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;
```

Dijalankan otomatis di `MigrationStrategy.onUpgrade`. Baris lama otomatis
aktif, jadi tidak ada user yang tiba-tiba terkunci. **Diuji pada database
seed asli** (`data/food_rescue.db`): server start, login ketiga peran tetap
jalan.

### App

| Layar | Isi |
|-------|-----|
| `admin_dashboard_screen.dart` | 3 tab: Pengguna / Makanan / Pesanan + 6 kartu statistik |
| `admin/admin_users_tab.dart` | Cari, filter peran, badge NONAKTIF, sheet detail, tangguhkan/aktifkan |
| `admin/admin_foods_tab.dart` | Katalog lintas toko: toko, harga, sisa, status |
| `admin/admin_orders_tab.dart` | Semua pesanan, filter status, nama toko per kartu |
| `change_password_screen.dart` | Password lama + baru + konfirmasi |
| `merchant_dashboard_screen.dart` | Menu "Kelola": ubah stok, edit detail, aktif/nonaktifkan |
| `profile_screen.dart` | Menu "Ubah Password", Pusat Bantuan (FAQ nyata), Tentang Aplikasi |

## 3. Hasil test

| Suite | Jumlah | Status |
|-------|--------|--------|
| Backend (`dart test`) | **165** | All passed |
| App (`flutter test`) | **92** | All passed |
| `dart analyze` | — | Bersih |

Test baru: `backend/test/admin_features_test.dart` (19), 
`backend/test/change_password_test.dart` (7).

## 4. Diverifikasi manual terhadap server sungguhan

```
GET  /admin/stats          -> suspended=0 portionsSaved=2 revenue=15000
GET  /admin/foods          -> total=4
GET  /admin/orders         -> total=3
GET  /admin/users?q=toko   -> 1 hasil
PATCH /admin/users/2       -> isActive=false
POST /auth/login (suspend) -> 403
GET  /auth/me (token lama) -> 403
PATCH /admin/users/2       -> isActive=true, login kembali 200
POST /auth/change-password (lama salah) -> 422
POST /auth/change-password (lama benar) -> 200, login password baru 200
```

## 5. Yang sengaja belum dibuat

| Fitur | Alasan |
|-------|--------|
| Ubah peran lewat API | Risiko eskalasi hak akses; cukup lewat seed CLI |
| Reset password tanpa login | Butuh verifikasi email; belum ada layanan email |
| Upload foto ke server | Satu file SQLite berisi foto pelanggan = risiko kebocoran |
| Notifikasi push | Butuh FCM + izin; di luar cakupan demo |
| Alamat pengambilan tersimpan | Butuh tabel alamat + relasi pesanan |

## 6. Cara demo

```powershell
# Terminal 1
cd backend
dart run bin/server.dart

# Terminal 2
cd food_rescue_app
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Akun: `buyer@foodrescue.id`, `toko@foodrescue.id`, `admin@foodrescue.id` —
password `DemoFood123`.

Alur demo admin: login admin → tab Pengguna → cari "buyer" → ketuk salah satu
→ "Tangguhkan akun" → coba login sebagai akun itu (gagal 403) → aktifkan lagi.
