// P10: test regresi untuk 5 bug yang dilaporkan reviewer (celineemercy).
//
// Setiap test di sini GAGAL pada kode sebelum perbaikan, jadi berfungsi
// sebagai bukti bahwa bug benar-benar diperbaiki.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/booking_provider.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/providers/orders_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/order_local_repository.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

const _userA = AuthUser(
  id: 1,
  name: 'Akun A',
  email: 'a@test.com',
  token: 'token-a',
);
const _userB = AuthUser(
  id: 2,
  name: 'Akun B',
  email: 'b@test.com',
  token: 'token-b',
);

Order _order(String id) => Order(
      id: id,
      pickupCode: 'RESCUE-$id',
      buyerName: 'William',
      surplusFoodName: 'Roti',
      quantity: 1,
      totalPrice: 10000,
      status: OrderStatus.pending,
      createdAt: DateTime(2026, 11, 15),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('#1 riwayat pesanan terpisah per akun', () {
    test('storage key memakai userId', () {
      expect(OrderLocalRepositoryImpl.keyFor(1), isNot(OrderLocalRepositoryImpl.keyFor(2)));
      expect(OrderLocalRepositoryImpl.keyFor(null),
          isNot(OrderLocalRepositoryImpl.keyFor(1)));
    });

    test('pesanan akun A tidak terlihat oleh akun B', () async {
      final repoA = OrderLocalRepositoryImpl(userId: 1);
      await repoA.saveOrder(_order('ord-a'));

      final repoB = OrderLocalRepositoryImpl(userId: 2);
      expect(await repoB.loadOrders(), isEmpty);

      // Akun A tetap melihat punyanya.
      expect(await repoA.loadOrders(), hasLength(1));
    });

    test('logout -> login akun lain memuat ulang riwayat', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).replaceUser(_userA);
      await container.read(ordersProvider.future);
      await container.read(ordersProvider.notifier).addOrder(_order('ord-a'));
      expect(container.read(ordersProvider).requireValue, hasLength(1));

      // Ganti akun.
      container.read(authProvider.notifier).replaceUser(_userB);
      await container.read(ordersProvider.future);
      expect(container.read(ordersProvider).requireValue, isEmpty);
    });

    test('data lama (key global) dimigrasikan ke akun aktif', () async {
      // Simulasikan storage versi lama.
      final legacy = OrderLocalRepositoryImpl(userId: 1);
      await legacy.saveOrder(_order('ord-lama'));
      // Pindahkan ke key lama secara manual.
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString(
        OrderLocalRepositoryImpl.keyFor(1),
      );
      await prefs.setString('food_rescue_orders', raw!);
      await prefs.remove(OrderLocalRepositoryImpl.keyFor(1));

      final migrated = await OrderLocalRepositoryImpl(userId: 1).loadOrders();
      expect(migrated, hasLength(1));
      expect(migrated.first.id, 'ord-lama');
      // Key lama sudah dibersihkan.
      expect(await prefs.getString('food_rescue_orders'), isNull);
    });
  });

  group('#2 sukses hanya setelah pesanan tersimpan', () {
    test('addOrder menulis ke storage sebelum state berubah', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).replaceUser(_userA);
      await container.read(ordersProvider.future);

      await container.read(ordersProvider.notifier).addOrder(_order('ord-1'));

      // Baca langsung dari storage: harus sudah ada.
      final stored = await OrderLocalRepositoryImpl(userId: 1).loadOrders();
      expect(stored.map((o) => o.id), contains('ord-1'));
    });
  });

  group('#3 foto bukti pengambilan disimpan', () {
    test('proofPhoto bertahan setelah diserialisasi', () {
      final order = _order('ord-1').copyWith(proofPhoto: 'BASE64DATA');

      final restored = Order.fromJson(
        jsonDecode(jsonEncode(order.toJson())) as Map<String, dynamic>,
      );

      expect(restored.proofPhoto, 'BASE64DATA');
    });

    test('markCompleted menyimpan proofPhoto ke storage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).replaceUser(_userA);
      await container.read(ordersProvider.future);
      await container.read(ordersProvider.notifier).addOrder(_order('ord-1'));

      await container
          .read(ordersProvider.notifier)
          .markCompleted('ord-1', proofPhoto: 'FOTO');

      final stored = await OrderLocalRepositoryImpl(userId: 1).loadOrders();
      expect(stored.single.status, OrderStatus.completed);
      expect(stored.single.proofPhoto, 'FOTO');
    });

    test('order tanpa bukti tetap bisa dibaca (data lama)', () {
      final json = _order('ord-lama').toJson();
      expect(json.containsKey('proofPhoto'), isFalse);

      final restored = Order.fromJson(json);
      expect(restored.proofPhoto, isNull);
    });
  });

  group('#4 userId dari sesi, bukan hard-code', () {
    test('body POST memakai userId yang dikirim', () async {
      Map<String, dynamic>? sent;

      final repo = ApiOrderRepository(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 209}), 201);
        }),
      );

      await repo.createOrder(
        buyerName: 'B',
        surplusFoodId: '16',
        surplusFoodName: 'Apple',
        quantity: 1,
        unitPrice: 1000,
        userId: 7,
      );

      expect(sent!['userId'], 7);
    });

    test('dua user berbeda mengirim userId berbeda', () async {
      final sentIds = <int>[];

      final repo = ApiOrderRepository(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentIds.add(body['userId'] as int);
          return http.Response(jsonEncode({'id': 1}), 201);
        }),
      );

      for (final id in [1, 2]) {
        await repo.createOrder(
          buyerName: 'X',
          surplusFoodId: '16',
          surplusFoodName: 'Apple',
          quantity: 1,
          unitPrice: 1000,
          userId: id,
        );
      }

      expect(sentIds, [1, 2]);
    });

    test('booking tanpa login ditolak', () async {
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider
              .overrideWithValue(FakeOrderRepository(delay: Duration.zero)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bookingProvider.notifier).submit(
            buyerName: 'X',
            surplusFoodId: '16',
            surplusFoodName: 'Apple',
            quantity: 1,
            unitPrice: 1000,
          );

      expect(container.read(bookingProvider).hasError, isTrue);
      expect(
        container.read(bookingProvider).error.toString(),
        contains('login'),
      );
    });
  });

  group('#5 kuota mengikuti stok nyata', () {
    test('quota = stock API apa adanya', () {
      final food = SurplusFood.fromJson({
        'id': 16,
        'title': 'Apple',
        'price': 1.99,
        'stock': 8,
        'category': 'groceries',
      });

      expect(food.quota, 8);
    });

    test('reduceQuota mengurangi sisa porsi di katalog', () async {
      final container = ProviderContainer(
        overrides: [
          surplusFoodRepositoryProvider.overrideWithValue(
            FakeSurplusFoodRepository(
              simulateFailureOnFirstCall: false,
              delay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final before = (await container.read(catalogProvider.future)).first;
      container.read(catalogProvider.notifier).reduceQuota(before.id, 2);

      final after = container
          .read(catalogProvider)
          .requireValue
          .firstWhere((f) => f.id == before.id);

      expect(after.quota, before.quota - 2);
    });

    test('reduceQuota tidak membuat kuota negatif', () {
      const food = SurplusFood(
        id: 'x',
        merchantName: 'M',
        name: 'N',
        description: 'D',
        originalPrice: 1000,
        discountPrice: 500,
        quota: 1,
        pickupWindow: '19:00 - 21:00',
        category: FoodCategory.main,
      );

      expect(food.copyWithQuota(-5).quota, 0);
    });
  });
}
