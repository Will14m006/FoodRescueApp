import 'package:food_rescue_backend/middleware/api_response.dart';
import 'package:food_rescue_backend/middleware/pagination.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'food_test.dart' show CatalogFixture;
import 'support.dart';

void main() {
  configureDriftForTests();
  late TestApi api;
  late CatalogFixture fixture;
  late String adminToken;
  late String merchantToken;
  late String buyerToken;

  setUp(() async {
    api = TestApi();
    fixture = CatalogFixture(api);
    adminToken = await createAdminToken(api);
    (merchantToken, _) = await fixture.merchant();
    (buyerToken, _, _) = await registerAndLogin(api);
  });
  tearDown(() => api.close());

  group('GET /admin/users', () {
    test('admin melihat semua user tanpa passwordHash', () async {
      final response =
          await api.request('GET', '/admin/users', token: adminToken);

      expect(response.statusCode, 200);
      final body = await api.json(response);
      expect(body['count'], greaterThanOrEqualTo(3));

      final text = body.toString();
      expect(text.contains('passwordHash'), isFalse);
      expect(text.contains(r'$2a$'), isFalse);
    });

    test('buyer / merchant → 403', () async {
      expect(
        (await api.request('GET', '/admin/users', token: buyerToken)).statusCode,
        403,
      );
      expect(
        (await api.request('GET', '/admin/users', token: merchantToken))
            .statusCode,
        403,
      );
    });

    test('tanpa token → 401', () async {
      expect((await api.request('GET', '/admin/users')).statusCode, 401);
    });

    test('filter ?role=merchant', () async {
      final body = await api.json(
        await api.request('GET', '/admin/users?role=merchant', token: adminToken),
      );

      expect(body['count'], 1);
      expect(((body['users'] as List).single as Map)['role'], 'merchant');
    });

    test('role tak dikenal → 422, bukan daftar kosong', () async {
      final response = await api.request(
        'GET',
        '/admin/users?role=superuser',
        token: adminToken,
      );
      expect(response.statusCode, 422);
    });

    test('paginasi limit & offset', () async {
      for (var i = 0; i < 5; i++) {
        await registerAndLogin(api, email: 'u$i@example.com');
      }

      final page1 = await api.json(await api.request(
        'GET',
        '/admin/users?limit=3&offset=0',
        token: adminToken,
      ));
      final page2 = await api.json(await api.request(
        'GET',
        '/admin/users?limit=3&offset=3',
        token: adminToken,
      ));

      expect(page1['count'], 3);
      expect(page2['count'], greaterThan(0));

      final ids1 = (page1['users'] as List).map((u) => (u as Map)['id']).toSet();
      final ids2 = (page2['users'] as List).map((u) => (u as Map)['id']).toSet();
      expect(ids1.intersection(ids2), isEmpty, reason: 'tidak boleh tumpang tindih');
    });

    test('limit di luar batas / negatif → 422', () async {
      for (final query in ['limit=0', 'limit=999', 'limit=abc', 'offset=-1']) {
        final response =
            await api.request('GET', '/admin/users?$query', token: adminToken);
        expect(response.statusCode, 422, reason: query);
      }
    });
  });

  group('GET /admin/stats', () {
    test('menghitung user, makanan, dan pesanan dengan benar', () async {
      final foodId = await fixture.food(merchantToken, quota: 3);
      await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': foodId,
        'quantity': 2,
      });

      final body = await api.json(
        await api.request('GET', '/admin/stats', token: adminToken),
      );

      final users = body['users'] as Map;
      expect(users['total'], 3);
      expect(users['admin'], 1);
      expect(users['merchant'], 1);
      expect(users['buyer'], 1);

      expect((body['foods'] as Map)['active'], 1);
      expect((body['foods'] as Map)['remainingQuota'], 1);

      final orders = body['orders'] as Map;
      expect(orders['total'], 1);
      expect(orders['pending'], 1);
      expect(orders['revenue'], 16000); // 8000 × 2
    });

    test('pesanan cancelled tidak masuk revenue', () async {
      final foodId = await fixture.food(merchantToken, quota: 3);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyerToken,
        body: {'foodId': foodId, 'quantity': 2},
      ));
      final orderId = (created['order'] as Map)['id'];

      await api.request('POST', '/orders/$orderId/cancel', token: buyerToken);

      final body = await api.json(
        await api.request('GET', '/admin/stats', token: adminToken),
      );
      final orders = body['orders'] as Map;
      expect(orders['cancelled'], 1);
      expect(orders['revenue'], 0);
    });

    test('database kosong → semua nol, bukan error', () async {
      final fresh = TestApi();
      addTearDown(fresh.close);
      final token = await createAdminToken(fresh);

      final body = await fresh.json(
        await fresh.request('GET', '/admin/stats', token: token),
      );

      expect((body['users'] as Map)['total'], 1);
      expect((body['orders'] as Map)['total'], 0);
      expect((body['orders'] as Map)['revenue'], 0);
      expect((body['foods'] as Map)['remainingQuota'], 0);
    });

    test('buyer → 403', () async {
      expect(
        (await api.request('GET', '/admin/stats', token: buyerToken)).statusCode,
        403,
      );
    });
  });

  group('GET /merchants/me/foods', () {
    test('menampilkan makanan nonaktif (beda dari katalog publik)', () async {
      final aktif = await fixture.food(merchantToken, name: 'Aktif');
      final nonaktif = await fixture.food(merchantToken, name: 'Nonaktif');
      await api.request('DELETE', '/foods/$nonaktif', token: merchantToken);

      final publik = await api.json(await api.request('GET', '/foods'));
      expect(publik['count'], 1);

      final dashboard = await api.json(
        await api.request('GET', '/merchants/me/foods', token: merchantToken),
      );
      expect(dashboard['count'], 2);
      expect(aktif, isNotNull);
    });

    test('merchant tidak melihat makanan toko lain', () async {
      final (other, _) = await fixture.merchant(
        email: 'other@example.com',
        storeName: 'Toko Lain',
      );
      await fixture.food(other, name: 'Milik Orang');

      final body = await api.json(
        await api.request('GET', '/merchants/me/foods', token: merchantToken),
      );
      expect(body['count'], 0);
    });

    test('buyer → 403', () async {
      expect(
        (await api.request('GET', '/merchants/me/foods', token: buyerToken))
            .statusCode,
        403,
      );
    });
  });

  group('GET /merchants/me/stats', () {
    test('ringkasan penjualan milik toko sendiri', () async {
      final foodId = await fixture.food(merchantToken, quota: 5);
      final created = await api.json(await api.request(
        'POST',
        '/orders',
        token: buyerToken,
        body: {'foodId': foodId, 'quantity': 2},
      ));
      final orderId = (created['order'] as Map)['id'];

      await api.request('POST', '/orders/$orderId/cancel', token: buyerToken);

      final body = await api.json(
        await api.request('GET', '/merchants/me/stats', token: merchantToken),
      );

      expect((body['foods'] as Map)['total'], 1);
      expect((body['foods'] as Map)['remainingQuota'], 5);
      expect((body['orders'] as Map)['total'], 1);
      expect((body['orders'] as Map)['cancelled'], 1);
      expect((body['orders'] as Map)['revenue'], 0);
      expect((body['orders'] as Map)['portionsSold'], 0);
    });

    test('tidak menghitung pesanan toko lain', () async {
      final foodId = await fixture.food(merchantToken, quota: 5);
      await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': foodId,
        'quantity': 1,
      });

      final (other, _) = await fixture.merchant(
        email: 'other@example.com',
        storeName: 'Toko Lain',
      );
      final otherStats = await api.json(
        await api.request('GET', '/merchants/me/stats', token: other),
      );

      expect((otherStats['orders'] as Map)['total'], 0);
      expect((otherStats['orders'] as Map)['revenue'], 0);
    });
  });

  group('hak istimewa admin tidak bisa didapat lewat HTTP', () {
    test('promosi diri jadi admin ditolak', () async {
      final response = await api.request('POST', '/auth/register', body: {
        'email': 'naik@example.com',
        'password': 'PasswordKuat123',
        'name': 'Naik',
        'role': 'admin',
      });
      expect(response.statusCode, 403);
    });

    test('tidak ada endpoint untuk mengubah role user', () async {
      // Coba beberapa bentuk yang mungkin "ditebak" penyerang.
      for (final path in ['/admin/users/1/role', '/users/1/role', '/admin/role']) {
        final response = await api.request(
          'PATCH',
          path,
          token: adminToken,
          body: {'role': 'admin'},
        );
        expect(response.statusCode, 404, reason: path);
      }
    });

    test('token merchant tidak bisa membaca /admin/stats', () async {
      expect(
        (await api.request('GET', '/admin/stats', token: merchantToken))
            .statusCode,
        403,
      );
    });
  });

  group('helper pagination', () {
    test('default limit 50, offset 0', () async {
      final page = readPagination(
        Request('GET', Uri.parse('http://x/admin/users')),
      );
      expect(page.limit, 50);
      expect(page.offset, 0);
    });

    test('menolak limit 0 dan > 200', () {
      expect(
        () => readPagination(Request('GET', Uri.parse('http://x/?limit=0'))),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => readPagination(Request('GET', Uri.parse('http://x/?limit=201'))),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
