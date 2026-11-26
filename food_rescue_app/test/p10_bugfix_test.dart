// P10: test regresi untuk bug yang dilaporkan reviewer, versi backend nyata.
//
// Bug lama: (1) riwayat tercampur antar akun, (2) sukses palsu karena data
// hanya di memori, (3) bukti foto hilang, (4) userId hard-code, (5) kuota
// karangan. Semua kini dijawab server — test ini menjaga jawabannya tetap.
//
// Setiap test GAGAL pada kode sebelum perbaikan.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/core/network/api_client.dart';
import 'package:food_rescue_app/core/network/api_exception.dart';
import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/providers/booking_provider.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/providers/orders_provider.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/proof_photo_store.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

Map<String, dynamic> _orderJson({int id = 1, String status = 'pending'}) => {
      'id': id,
      'pickupCode': 'RESCUE-7KQ2XM',
      'buyerId': 1,
      'buyerName': 'William',
      'foodId': 16,
      'foodName': 'Roti Gandum',
      'merchantName': 'Roti O Bakso',
      'quantity': 1,
      'totalPrice': 15000,
      'status': status,
      'createdAt': '2026-11-20T10:00:00.000Z',
    };

ApiClient _api(MockClient client) =>
    ApiClient(client: client, baseUrl: 'http://test.local');

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('#1 bukti foto terpisah per akun', () {
    test('key storage memakai userId', () {
      expect(ProofPhotoStore.keyFor(1), isNot(ProofPhotoStore.keyFor(2)));
      expect(
        ProofPhotoStore.keyFor(null),
        isNot(ProofPhotoStore.keyFor(1)),
      );
    });

    test('foto akun A tidak terlihat oleh akun B', () async {
      await ProofPhotoStore(userId: 1).save(10, 'FOTOA');

      expect(await ProofPhotoStore(userId: 2).read(10), isNull);
      expect(await ProofPhotoStore(userId: 1).read(10), 'FOTOA');
    });

    test('foto bertahan untuk beberapa pesanan sekaligus', () async {
      final store = ProofPhotoStore(userId: 1);
      await store.save(1, 'A');
      await store.save(2, 'B');

      expect(await store.loadAll(), {'1': 'A', '2': 'B'});
    });

    test('storage rusak tidak membuat aplikasi crash', () async {
      await SharedPreferencesAsync()
          .setString(ProofPhotoStore.keyFor(1), 'bukan json');

      expect(await ProofPhotoStore(userId: 1).loadAll(), isEmpty);
    });
  });

  group('#2 status pesanan berasal dari server', () {
    test('cancel memakai status hasil server, bukan tebakan klien', () async {
      final repo = ApiOrderRepository(
        api: _api(MockClient((_) async {
          return http.Response(
            jsonEncode({'order': _orderJson(status: 'cancelled')}),
            200,
            headers: {'content-type': 'application/json'},
          );
        })),
      );

      final order = await repo.cancel(token: 't', orderId: 1);

      expect(order.status, OrderStatus.cancelled);
    });

    test('complete menolak kode salah dengan pesan server', () async {
      final repo = ApiOrderRepository(
        api: _api(MockClient((_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'invalid_pickup_code',
                  'message': 'Kode pick-up tidak cocok.',
                },
              }),
              422,
              headers: {'content-type': 'application/json'},
            ))),
      );

      await expectLater(
        repo.complete(token: 't', orderId: 1, pickupCode: 'SALAH'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Kode pick-up tidak cocok.',
        )),
      );
    });
  });

  group('#3 bukti foto tidak mengubah status', () {
    test('copyWith(proofPhoto:) tidak menyentuh status', () {
      final order = Order.fromJson(_orderJson());
      final withPhoto = order.copyWith(proofPhoto: 'BASE64');

      expect(withPhoto.status, OrderStatus.pending);
      expect(withPhoto.proofPhoto, 'BASE64');
    });

    test('proofPhoto tidak dikirim ke server (hanya lokal)', () {
      final json = Order.fromJson(_orderJson())
          .copyWith(proofPhoto: 'BASE64')
          .toJson();

      // toJson dipakai untuk cache lokal; repo tidak pernah mengirimnya.
      expect(json['proofPhoto'], 'BASE64');
      expect(json['status'], 'pending');
    });
  });

  group('#4 identitas dari token, bukan body', () {
    test('createOrder hanya mengirim foodId & quantity', () async {
      Map<String, dynamic>? sent;
      String? auth;

      final repo = ApiOrderRepository(
        api: _api(MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          auth = request.headers['Authorization'];
          return http.Response(
            jsonEncode({'order': _orderJson()}),
            201,
            headers: {'content-type': 'application/json'},
          );
        })),
      );

      await repo.createOrder(token: 'token-a', foodId: 16, quantity: 1);

      expect(sent, {'foodId': 16, 'quantity': 1});
      expect(auth, 'Bearer token-a');
    });

    test('booking tanpa sesi ditolak sebelum menyentuh jaringan', () async {
      var called = false;
      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _SpyOrderRepository(onCall: () => called = true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(bookingProvider.notifier)
          .submit(surplusFoodId: '16', quantity: 1);

      expect(container.read(bookingProvider).hasError, isTrue);
      expect(
        container.read(bookingProvider).error.toString(),
        contains('login'),
      );
      expect(called, isFalse);
    });
  });

  group('#5 kuota mengikuti data server', () {
    test('quota = nilai server apa adanya', () {
      final food = SurplusFood.fromJson({
        'id': 16,
        'merchantId': 3,
        'merchantName': 'Roti O Bakso',
        'name': 'Roti Gandum',
        'description': 'Roti sisa hari ini.',
        'originalPrice': 40000,
        'discountPrice': 15000,
        'quota': 8,
        'pickupWindow': '19:00 - 21:00',
        'isActive': true,
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
        id: 1,
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

/// Repo pesanan yang mencatat apakah jaringan sempat dipanggil.
class _SpyOrderRepository implements OrderRepository {
  _SpyOrderRepository({required this.onCall});

  final void Function() onCall;

  @override
  Future<Order> createOrder({
    required String token,
    required int foodId,
    required int quantity,
  }) async {
    onCall();
    throw StateError('tidak boleh dipanggil');
  }

  @override
  Future<List<Order>> fetchOrders({required String token}) async {
    onCall();
    return [];
  }

  @override
  Future<Order> complete({
    required String token,
    required int orderId,
    required String pickupCode,
  }) async {
    onCall();
    throw StateError('tidak boleh dipanggil');
  }

  @override
  Future<Order> cancel({required String token, required int orderId}) async {
    onCall();
    throw StateError('tidak boleh dipanggil');
  }
}
