# P5: Local Data & Persistence Documentation

> "Implementasikan konsep Local Data & Persistence pada project yang sudah kalian buat."

## 1. Fitur yang Diimplementasikan

**Status Pesanan + Riwayat Pesanan** — keduanya membaca data lokal yang sama,
tapi dibagi dua layar sesuai fungsinya:

* **Status Pesanan** (`/order-status`) — pengguna melihat status pesanannya dan
  bisa **mengubah status** (Sudah Pickup / Batalkan) atau **menghapus** pesanan
  yang sudah selesai.
* **Riwayat Pesanan** (`/orders`) — **read-only**. Pengguna hanya bisa melihat
  data pesanan yang tersimpan; tidak ada tombol hapus atau ubah status.

Saat pengguna berhasil memesan makanan (Fitur 2: Booking), pesanan langsung
disimpan ke local storage. Pesanan ini **tetap ada** setelah aplikasi ditutup
dan dibuka lagi (atau setelah browser di-refresh).

Alur vertikal: **FE Booking → Local Storage → Status Pesanan (aksi) & Riwayat
Pesanan (lihat)**.

## 2. Posisi Code Local Data & Persistence

```
lib/
├── models/
│   └── order_model.dart                     ← DATA MODEL (entity + toJson/fromJson)
├── repositories/
│   └── order_local_repository.dart          ← LOCAL STORAGE (SharedPreferences + JSON)
├── providers/
│   └── orders_provider.dart                 ← STATE (operasi CRUD)
└── screens/
    ├── order_status_screen.dart             ← UI: lihat status + aksi Update/Delete
    └── orders_screen.dart                   ← UI: Riwayat Pesanan (read-only)
```

### a. Data Model — `lib/models/order_model.dart`

`Order` adalah entity yang disimpan, lengkap dengan serialisasi:

```dart
class Order {
  final String id;
  final String pickupCode;
  final String buyerName;
  final String surplusFoodName;
  final int quantity;
  final int totalPrice;
  final OrderStatus status;   // pending / completed / cancelled
  final DateTime createdAt;

  Map<String, dynamic> toJson();
  factory Order.fromJson(Map<String, dynamic> json);
}
```

`OrderStatus` punya mapping ke JSON string (`jsonValue` / `fromJsonValue`) dan
warna badge sesuai aturan arsitektur (PENDING oranye, COMPLETED hijau,
CANCELLED merah).

### b. Storage — `lib/repositories/order_local_repository.dart`

Kontrak abstrak + implementasi memakai **SharedPreferences**:

```dart
abstract class OrderLocalRepository {
  Future<List<Order>> loadOrders();                              // READ
  Future<void> saveOrder(Order order);                           // CREATE
  Future<void> updateOrderStatus(String orderId, OrderStatus status);  // UPDATE
  Future<void> deleteOrder(String orderId);                      // DELETE
  Future<void> clearAll();
}
```

Data disimpan sebagai **JSON string** di key `food_rescue_orders`. Karena
`Order` berupa list of object, dilakukan `jsonEncode`/`jsonDecode` manual.

**Kenapa SharedPreferences?** Di platform **web**, implementasinya otomatis
jatuh ke **localStorage browser** (via plugin `shared_preferences_web`).
Di Android/iOS memakai SharedPreferences native. Jadi sekali tulis, jalan di
semua platform — persis seperti instruksi P5 ("Flutter: shared_preferences").

## 3. Implementasi CRUD

| Operasi | Method | Trigger di UI |
|---------|--------|---------------|
| **Create** | `OrdersNotifier.addOrder()` | Otomatis saat booking sukses (`booking_screen.dart`) |
| **Read** | `OrdersNotifier.build()` → `loadOrders()` | Status Pesanan & Riwayat Pesanan dibuka |
| **Update** | `markCompleted()` / `markCancelled()` | Tombol "Sudah Pickup" / "Batalkan" di **Status Pesanan** |
| **Delete** | `deleteOrder()` | Tombol "Hapus Pesanan" di **Status Pesanan** (hanya untuk pesanan yang sudah selesai/dibatalkan) |

> **Catatan pemisahan layar:** Riwayat Pesanan sengaja dibuat **read-only** —
> pengguna tidak boleh mengubah atau menghapus riwayatnya. Semua aksi Update &
> Delete ada di Status Pesanan. Aksi Update hanya muncul untuk pesanan yang
> masih `pending`; aksi Delete hanya muncul untuk pesanan yang sudah selesai /
> dibatalkan.

Semua operasi langsung tulis ke storage, lalu state di-refresh dari storage
(bukan dari memory). Ini memastikan yang ditampilkan selalu sama dengan yang
tersimpan.

### State Management — `lib/providers/orders_provider.dart`

```dart
class OrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    return _repository().loadOrders();      // load saat app dibuka
  }

  Future<void> addOrder(Order order) async {
    await _repository().saveOrder(order);   // tulis ke storage
    state = AsyncData(await _repository().loadOrders());  // refresh dari storage
  }
  // ... markCompleted, markCancelled, deleteOrder, refresh
}
```

## 4. Persistence Test

File: `test/orders_persistence_test.dart` (10 test, semua lulus).

Plus integration test alur lengkap: `test/booking_to_orders_test.dart`
(login → pesan → status pesanan → update status → riwayat pesanan).

Test terpenting membuktikan data **tetap ada setelah aplikasi ditutup & dibuka
lagi**:

```dart
test('Persistence: data tetap ada setelah repository di-instantiate ulang', () async {
  await repo.saveOrder(_createOrder(id: 'ord-1'));

  // Simulasi restart: instance lama dibuang, instance baru dibuat dengan
  // storage yang sama. Kalau data hanya di memory, ini pasti kosong.
  final reopenedRepo = OrderLocalRepositoryImpl(prefsWithOverrides: [prefs]);

  final orders = await reopenedRepo.loadOrders();

  expect(orders, hasLength(1));
  expect(orders.first.id, 'ord-1');
});
```

Logic-nya: `OrderLocalRepositoryImpl` tidak memegang data di memory sama sekali.
Setiap method membaca/menulis langsung ke storage. Jadi saat instance baru
dibuat ("aplikasi dibuka ulang"), data harus tetap bisa dibaca — inilah
persistence test-nya.

Untuk test browser refresh, `SharedPreferencesAsync` membaca dari storage saat
pertama diakses, jadi instance baru (`SharedPreferencesAsync()`) yang membaca
storage yang sama akan mendapat data yang sama.

## 5. Cara Demo ke Reviewer

Jalankan aplikasi:

```bash
cd food_rescue_app
flutter run -d chrome
```

Lalu:

1. **Create** — Login → pilih makanan → isi form → tekan "Pesan Sekarang".
   Pesanan tersimpan ke localStorage.
2. **Read** — Buka **Status Pesanan** (ikon receipt di header dashboard, atau
   menu Profile → Status Pesanan). Pesanan muncul dengan status MENUNGGU.
   Buka juga **Riwayat Pesanan** (ikon history di header, atau menu Profile →
   Riwayat Pesanan) — pesanan yang sama muncul tanpa tombol aksi.
3. **Persistence** — **Refresh browser (F5)**. Buka Status Pesanan / Riwayat
   Pesanan lagi. Pesanan masih ada! (bisa dicek juga via DevTools → Application
   → Local Storage).
4. **Update** — Di Status Pesanan, tekan "Sudah Pickup" (status jadi SELESAI /
   hijau) atau "Batalkan" (status jadi DIBATALKAN / merah). Refresh lagi →
   perubahan tetap.
5. **Delete** — Pesanan yang sudah selesai/dibatalkan menampilkan tombol
   "Hapus Pesanan". Tekan, lalu refresh → pesanan hilang permanen.

Cek storage langsung di browser: DevTools (F12) → tab **Application** →
**Local Storage** → `http://localhost:xxxxx` → key `food_rescue_orders`.

## 6. Prompt AI yang Digunakan

* "Implementasikan Local Data & Persistence dengan SharedPreferences: simpan
  riwayat pesanan secara lokal, lengkap dengan operasi CRUD."
* "Buat persistence test yang membuktikan data tetap ada setelah aplikasi
  di-instantiate ulang (simulasi restart)."
* "Bagaimana cara mock SharedPreferencesAsync di unit test?" — jawabannya
  memakai `InMemorySharedPreferencesAsync` dari `shared_preferences_platform_interface`.

## 7. Bagian yang Saya Periksa / Perbaiki Sendiri

* Memastikan repository **tidak menyimpan data di memory** — semua operasi
  langsung membaca/menulis storage, supaya persistence test-nya benar-benar
  membuktikan data bertahan, bukan sekadar cache.
* Menambahkan `==` dan `hashCode` di `Order` agar test round-trip
  serialisasi bisa membandingkan objek dengan benar.
* Mencari tahu API test yang benar untuk `SharedPreferencesAsync` (API baru),
  yang ternyata memerlukan `InMemorySharedPreferencesAsync`, bukan
  `setMockInitialValues` (itu untuk API lama `SharedPreferences`).
* Menghubungkan booking sukses agar otomatis menyimpan ke local storage, dan
  memastikan platform instance disiapkan di seluruh test yang terdampak.
