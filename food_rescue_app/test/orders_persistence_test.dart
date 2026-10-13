// Test untuk P5: Local Data & Persistence.
//
// Menguji:Create, Read, Update, Delete, dan Persistence
// (data tetap ada setelah repository "dibuka ulang" / aplikasi di-refresh).
//
// SharedPreferences di-override dengan instance test sehingga test
// deterministik dan tidak menyentuh storage asli perangkat.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/repositories/order_local_repository.dart';

Order _createOrder({
  required String id,
  String pickupCode = 'RESCUE-101',
  OrderStatus status = OrderStatus.pending,
}) {
  return Order(
    id: id,
    pickupCode: pickupCode,
    buyerName: 'William',
    surplusFoodName: 'Paket Roti Sisa Hari Ini',
    quantity: 2,
    totalPrice: 30000,
    status: status,
    createdAt: DateTime(2026, 10, 9, 19, 30),
  );
}

void main() {
  late SharedPreferencesAsync prefs;
  late OrderLocalRepositoryImpl repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock storage dengan instance in-memory (API SharedPreferencesAsync).
    final mock = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = mock;

    prefs = SharedPreferencesAsync();
    repo = OrderLocalRepositoryImpl(prefsWithOverrides: [prefs]);
  });

  test('Read: awalnya kosong saat belum ada data tersimpan', () async {
    expect(await repo.loadOrders(), isEmpty);
  });

  test('Create & Read: pesanan tersimpan dan bisa dibaca kembali', () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));

    final orders = await repo.loadOrders();

    expect(orders.length, 1);
    expect(orders.first.id, 'ord-1');
    expect(orders.first.pickupCode, 'RESCUE-101');
    expect(orders.first.buyerName, 'William');
    expect(orders.first.quantity, 2);
    expect(orders.first.totalPrice, 30000);
    expect(orders.first.status, OrderStatus.pending);
  });

  test('Update: status pesanan bisa diubah menjadi completed', () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));
    await repo.updateOrderStatus('ord-1', OrderStatus.completed);

    final orders = await repo.loadOrders();

    expect(orders.first.status, OrderStatus.completed);
    // Field lain tetap utuh, hanya status yang berubah.
    expect(orders.first.pickupCode, 'RESCUE-101');
    expect(orders.first.buyerName, 'William');
  });

  test('Update: status pesanan bisa diubah menjadi cancelled', () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));
    await repo.updateOrderStatus('ord-1', OrderStatus.cancelled);

    expect((await repo.loadOrders()).first.status, OrderStatus.cancelled);
  });

  test('Delete: pesanan bisa dihapus dari storage', () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));
    await repo.saveOrder(_createOrder(id: 'ord-2', pickupCode: 'RESCUE-102'));
    expect(await repo.loadOrders(), hasLength(2));

    await repo.deleteOrder('ord-1');

    final orders = await repo.loadOrders();
    expect(orders, hasLength(1));
    expect(orders.first.id, 'ord-2');
    expect(orders.first.pickupCode, 'RESCUE-102');
  });

  test(
      'Persistence: data tetap ada setelah repository di-instantiate ulang '
      "(simulasi aplikasi ditutup lalu dibuka lagi)", () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));
    await repo.updateOrderStatus('ord-1', OrderStatus.completed);

    // Simulasi restart: instance lama dibuang, instance baru dibuat dengan
    // storage yang sama. Kalau data hanya di memory, ini pasti kosong.
    final reopenedRepo = OrderLocalRepositoryImpl(prefsWithOverrides: [prefs]);

    final orders = await reopenedRepo.loadOrders();

    expect(orders, hasLength(1));
    expect(orders.first.id, 'ord-1');
    expect(orders.first.status, OrderStatus.completed);
  });

  test('Persistence: data bertahan setelah browser di-refresh (web storage)',
      () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));

    // SharedPreferencesAsync memakai cache in-memory, lalu membaca dari
    // storage saat pertama kali diakses. Simulasi "refresh" dengan
    // mengosongkan cache lalu membaca ulang dari storage.
    final reopenedPrefs = SharedPreferencesAsync();
    final reopenedRepo =
        OrderLocalRepositoryImpl(prefsWithOverrides: [reopenedPrefs]);

    final orders = await reopenedRepo.loadOrders();

    expect(orders, hasLength(1));
    expect(orders.first.id, 'ord-1');
  });

  test('Create multiple: pesanan baru selalu muncul di urutan teratas', () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));
    await repo.saveOrder(_createOrder(id: 'ord-2'));

    final orders = await repo.loadOrders();

    expect(orders.first.id, 'ord-2');
    expect(orders.last.id, 'ord-1');
  });

  test('Clear: semua pesanan bisa dihapus sekaligus', () async {
    await repo.saveOrder(_createOrder(id: 'ord-1'));
    await repo.saveOrder(_createOrder(id: 'ord-2'));

    await repo.clearAll();

    expect(await repo.loadOrders(), isEmpty);
  });

  test('Serialisasi: Order toJson/fromJson bersifat round-trip', () {
    final order = _createOrder(id: 'ord-1');
    final json = order.toJson();

    expect(Order.fromJson(json), equals(order));
  });
}
