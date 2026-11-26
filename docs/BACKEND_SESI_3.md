# Backend — Sesi 3: Katalog & Pesanan (Kuota Transaksional)

Sesi ini menambahkan inti bisnis Food Rescue: merchant menjual makanan surplus,
buyer memesan, dan **kuota tidak pernah bisa minus** walau dua orang memesan
unit terakhir pada milidetik yang sama.

## Endpoint

### Toko (merchant)

| Method | Path | Keterangan |
|---|---|---|
| PUT | `/merchants/me` | upsert nama toko; wajib sebelum membuat makanan |
| GET | `/merchants/me` | profil toko sendiri |

### Katalog

| Method | Path | Akses | Keterangan |
|---|---|---|---|
| GET | `/foods` | publik | hanya `isActive` dan `quota > 0`; `?q=` cari nama makanan **atau** nama toko |
| GET | `/foods/<id>` | publik | detail |
| POST | `/foods` | merchant | butuh profil toko |
| PATCH | `/foods/<id>` | merchant pemilik | ubah sebagian field |
| DELETE | `/foods/<id>` | merchant pemilik | **soft delete** (`isActive=false`) |

### Pesanan

| Method | Path | Akses | Keterangan |
|---|---|---|---|
| POST | `/orders` | buyer | potong kuota + buat pesanan, satu transaksi |
| GET | `/orders` | login | buyer: miliknya · merchant: tokonya · admin: semua |
| GET | `/orders/<id>` | pemilik / merchant toko / admin | selain itu **404** |
| POST | `/orders/<id>/complete` | merchant toko / admin | **wajib** kirim `pickupCode` |
| POST | `/orders/<id>/cancel` | pembeli / merchant toko / admin | kuota dikembalikan |

Contoh:

```powershell
# merchant
$m = curl.exe -s -X POST http://127.0.0.1:8080/auth/register -H "Content-Type: application/json" `
  -d '{\"email\":\"toko@x.com\",\"password\":\"PasswordKuat123\",\"name\":\"Siti\",\"role\":\"merchant\"}'
# PUT /merchants/me  {"storeName":"Warung Bu Siti"}
# POST /foods  {"name":"Nasi Goreng Sisa","originalPrice":25000,"discountPrice":9000,"quota":1,"pickupWindow":"19:00 - 21:00"}

# buyer
# POST /orders  {"foodId":1,"quantity":1}
# → 201 {"order":{...,"pickupCode":"RESCUE-2HCAUA2M","totalPrice":9000,"status":"pending"}}
```

## Bagian terpenting: kuota transaksional

Masalahnya sederhana untuk ditulis, sulit untuk benar:

> Kuota 1. Dua pembeli menekan "Pesan" bersamaan. Berapa yang berhasil?

Pola naif `SELECT kuota` → `if (kuota >= qty)` → `UPDATE kuota - qty` **gagal**
di sini: keduanya membaca `1`, keduanya lolos pengecekan, lalu keduanya menulis
`0` — dua pesanan terjual dari satu porsi.

Yang dipakai di `_createOrder`, semuanya di dalam `db.transaction`:

```dart
final reserved = await (db.update(db.surplusFoods)
      ..where((t) => t.id.equals(foodId))
      ..where((t) => t.quota.isBiggerOrEqualValue(quantity)))
    .write(SurplusFoodsCompanion.custom(
      quota: db.surplusFoods.quota - Variable<int>(quantity),
    ));

if (reserved == 0) throw ApiException(409, '…', code: 'insufficient_quota');
```

Kuncinya: **pengecekan kuota ada di `WHERE`, bukan di Dart.** `UPDATE ... WHERE
quota >= ?` adalah satu statement atomik — SQLite mengevaluasi `WHERE` dan
menulis dalam satu langkah, jadi pembeli kedua mendapat **0 baris terpengaruh**,
bukan kuota minus. Kalau `reserved == 0`, transaksi dibatalkan tanpa menyentuh
tabel `orders`.

Dua lapis pengaman:
1. Cek awal `food.quota < quantity` → pesan error yang informatif ("Kuota
   tersisa 3, tidak cukup untuk 5 porsi").
2. `WHERE quota >= ?` → penentu akhir kalau ada request lain di antaranya.

### Bukti

Test otomatis (`test/order_test.dart`):

| Skenario | Hasil |
|---|---|
| 2 request paralel, kuota 1 | tepat **1×201**, 1×409, kuota **0** |
| 20 request paralel, kuota 5 | tepat **5×201**, 15×409, kuota **0** |
| quantity 6 dari kuota 5 | 409, kuota tetap 5, tabel orders kosong |

Uji manual lewat HTTP sungguhan (dua `Start-Job` paralel):

```
201|{"order":{"id":1,"pickupCode":"RESCUE-2HCAUA2M",...}}
409|{"error":{"code":"insufficient_quota","message":"Kuota tersisa 0, tidak cukup 1 porsi."}}
kuota setelah race: 0
```

Kuota **0**, bukan `-1`.

## Keputusan (dan alasannya)

| # | Keputusan | Alternatif yang ditolak | Kenapa |
|---|---|---|---|
| 1 | Potong kuota lewat `UPDATE … WHERE quota >= ?` | `SELECT` lalu `if` di Dart | Cek-dan-tulis harus satu statement atomik; kalau tidak, dua pembeli bisa menang bersamaan |
| 2 | Seluruh pembuatan pesanan di `db.transaction` | insert lalu update terpisah | Kalau insert gagal setelah kuota dipotong, kuota hilang tanpa pesanan (dan tanpa cara mengembalikannya) |
| 3 | **Pembatalan** juga transaksional: status + kuota bersama | update status saja | Kuota bisa hilang (batal tanpa refund) atau dobel (refund dua kali) |
| 4 | Refund memakai `UPDATE … WHERE status = 'pending'` (`_setStatus`) | baca status lalu update | Dua klik "Batalkan" bersamaan tidak boleh mengembalikan kuota dua kali. Test: batal 2× → 409, kuota tetap 5 (bukan 7) |
| 5 | `pickupCode` di-**generate server** (32⁸ ≈ 1,1×10¹² kemungkinan) | kode dari klien / turunan id | Kalau klien yang membuat, kode bisa ditebak (`RESCUE-1`, `RESCUE-2`) dan pesanan orang lain bisa diambil. Pakai `Random.secure()` |
| 6 | Alfabet kode tanpa `0 O 1 I L` | A-Z0-9 penuh | Kode dibacakan/ditunjukkan di kasir; `0` vs `O` adalah sumber salah input |
| 7 | `complete` **wajib** mengirim ulang `pickupCode` | cukup `POST /complete` | Tanpa ini, merchant bisa menekan "Selesai" pada pesanan mana pun tanpa melihat kode — validasi jadi formalitas |
| 8 | `DELETE /foods` = soft delete | `DELETE` baris | Pesanan lama harus tetap bisa menunjuk makanannya (Architecture.md §5). Baris tetap ada, hanya hilang dari katalog |
| 9 | Makanan milik merchant lain → **404**, bukan 403 | 403 | 403 mengonfirmasi "id ini ada, tapi bukan milikmu". 404 tidak membocorkan apa pun |
| 10 | Pesanan orang lain → **404** juga | 403 | Sama: keberadaan pesanan bukan informasi publik |
| 11 | Buyer tidak bisa memesan makanan nonaktif → 404 | 409 | Makanan nonaktif secara efektif "tidak ada" di katalog publik |
| 12 | Harga dihitung server (`discountPrice × quantity`) | kirim `totalPrice` dari klien | Klien yang menghitung total = klien yang bisa memesan Rp 9.000 dengan total Rp 1 |
| 13 | `discountPrice > originalPrice` → 422 | terima apa adanya | Diskon negatif merusak tampilan harga coret di aplikasi |
| 14 | Role `merchant`/`admin` tidak bisa `POST /orders` → 403 | izinkan | Pesanan punya `buyerId`; merchant yang memesan akan mengotori laporan penjualannya sendiri |
| 15 | Data pesanan memuat `buyerName`/`foodName`/`merchantName`, **tanpa email** | kirim objek user utuh | Aplikasi hanya butuh nama; email pembeli tidak ada urgensinya di struk merchant |
| 16 | Nama merchant diambil satu query untuk semua baris (`merchantNames`) | query per makanan | Menghindari N+1 di katalog |

## Perubahan skema

Satu perubahan kecil, **tanpa migrasi data**:

```dart
// sebelum
TextColumn get status => text().withDefault(const Constant('PENDING'))();
// sesudah
TextColumn get status =>
    textEnum<OrderStatus>().withDefault(const Constant('pending'))();
```

Kolomnya tetap `TEXT`; hanya tipenya di Dart yang jadi `enum OrderStatus`
(`pending`/`completed`/`cancelled`) — sesuai `OrderStatusX.jsonValue` yang
sudah dipakai aplikasi Flutter. `schemaVersion` tetap **1**. Database lokal
dihapus saat pengembangan, jadi tidak ada baris lama berisi `PENDING` kapital.

## Bukti yang dijalankan

```
dart analyze  -> No issues found!
dart test     -> 105 / 105 lulus
```

Penambahan dari sesi 2: `food_test.dart` (21) + `order_test.dart` (22).

Uji manual terhadap server sungguhan:

| Uji | Hasil |
|---|---|
| register merchant → `PUT /merchants/me` → `POST /foods` | 201 / 200 / 201 |
| `GET /foods` tanpa token | 200, `merchantName` ikut |
| 2 buyer paralel, kuota 1 | 201 + 409, kuota 0 |
| `complete` dengan kode benar | 200 → `completed` |
| `complete` ulang | 409 |
| `complete` kode salah | 422, status tetap `pending` |
| `cancel` | 200 → `cancelled`, kuota 3 kembali dari 1 |
| buyer B membuka pesanan buyer A | 404 |
| log server | 0 `[ERROR]`, 0 stack trace, 0 pickupCode |

## Yang sengaja belum dibuat

| Belum | Alasan / kapan |
|---|---|
| Pagination katalog | Jumlah makanan per demo kecil; `?limit&offset` saat katalog > 100 |
| Upload foto makanan | Butuh storage; aplikasi masih memakai emoji |
| `GET /orders?status=` filter | Aplikasi memfilter di klien; tambah saat riwayat panjang |
| Refund saat merchant menonaktifkan makanan | Pesanan `pending` yang sudah ada tetap boleh diselesaikan — perilaku yang benar |
| Seed data demo | **Sesi 4** (bersama akun admin) |
| Dashboard admin & statistik | Sesi 4 |

## Langkah sesi 4

Seed CLI (admin + contoh toko/makanan), route admin (`GET /users`,
`GET /admin/stats`), dan endpoint `GET /merchants/<id>/foods` untuk dashboard
merchant. Test: admin bisa melihat semua pesanan, merchant tidak bisa melihat
pesanan toko lain di `/admin/*` (403).
