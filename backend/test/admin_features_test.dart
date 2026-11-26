import 'package:test/test.dart';

import 'food_test.dart' show CatalogFixture;
import 'support.dart';

/// Fitur admin tambahan: penangguhan akun, detail user, daftar makanan &
/// pesanan lintas toko.
void main() {
  configureDriftForTests();
  late TestApi api;
  late CatalogFixture fixture;
  late String adminToken;
  late String buyerToken;
  late int buyerId;
  late String merchantToken;

  setUp(() async {
    api = TestApi();
    fixture = CatalogFixture(api);
    adminToken = await createAdminToken(api);
    final registered = await registerAndLogin(api);
    buyerToken = registered.$1;
    buyerId = registered.$2['id'] as int;
    (merchantToken, _) = await fixture.merchant();
  });
  tearDown(() => api.close());

  group('PATCH /admin/users/<id>', () {
    test('admin menangguhkan akun', () async {
      final response = await api.request(
        'PATCH',
        '/admin/users/$buyerId',
        token: adminToken,
        body: {'isActive': false},
      );

      expect(response.statusCode, 200);
      final body = await api.json(response);
      expect((body['user'] as Map)['isActive'], isFalse);
    });

    test('akun ditangguhkan tidak bisa login', () async {
      await api.request(
        'PATCH',
        '/admin/users/$buyerId',
        token: adminToken,
        body: {'isActive': false},
      );

      final response = await api.request('POST', '/auth/login', body: {
        'email': 'buyer@example.com',
        'password': 'PasswordKuat123',
      });
      expect(response.statusCode, 403);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'account_suspended');
    });

    test('token lama langsung tidak berlaku setelah ditangguhkan', () async {
      expect(
        (await api.request('GET', '/auth/me', token: buyerToken)).statusCode,
        200,
      );

      await api.request(
        'PATCH',
        '/admin/users/$buyerId',
        token: adminToken,
        body: {'isActive': false},
      );

      expect(
        (await api.request('GET', '/auth/me', token: buyerToken)).statusCode,
        403,
      );
    });

    test('menangguhkan lalu mengaktifkan lagi memulihkan login', () async {
      for (final active in [false, true]) {
        await api.request(
          'PATCH',
          '/admin/users/$buyerId',
          token: adminToken,
          body: {'isActive': active},
        );
      }

      final response = await api.request('POST', '/auth/login', body: {
        'email': 'buyer@example.com',
        'password': 'PasswordKuat123',
      });
      expect(response.statusCode, 200);
    });

    test('mengubah role lewat sini ditolak 422', () async {
      final response = await api.request(
        'PATCH',
        '/admin/users/$buyerId',
        token: adminToken,
        body: {'role': 'admin'},
      );

      expect(response.statusCode, 422);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'immutable_field');
    });

    test('admin tidak bisa menangguhkan dirinya sendiri', () async {
      final me = await api.json(
        await api.request('GET', '/auth/me', token: adminToken),
      );
      final adminId = (me['user'] as Map)['id'] as int;

      final response = await api.request(
        'PATCH',
        '/admin/users/$adminId',
        token: adminToken,
        body: {'isActive': false},
      );

      expect(response.statusCode, 409);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'self_suspend');
    });

    test('buyer tidak bisa memakai endpoint ini â†’ 403', () async {
      final response = await api.request(
        'PATCH',
        '/admin/users/$buyerId',
        token: buyerToken,
        body: {'isActive': false},
      );
      expect(response.statusCode, 403);
    });

    test('user tidak dikenal â†’ 404', () async {
      expect(
        (await api.request(
          'PATCH',
          '/admin/users/999999',
          token: adminToken,
          body: {'isActive': false},
        ))
            .statusCode,
        404,
      );
    });
  });

  group('GET /admin/users/<id>', () {
    test('mengembalikan user + jumlah pesanan', () async {
      final response = await api.request(
        'GET',
        '/admin/users/$buyerId',
        token: adminToken,
      );

      expect(response.statusCode, 200);
      final body = await api.json(response);
      expect((body['user'] as Map)['id'], buyerId);
      expect((body['stats'] as Map)['orders'], isA<int>());
      expect((body['stats'] as Map)['spent'], isA<int>());
    });

    test('tidak membocorkan passwordHash', () async {
      final body = await api.json(
        await api.request('GET', '/admin/users/$buyerId', token: adminToken),
      );
      expect(body.toString().contains('passwordHash'), isFalse);
    });
  });

  group('GET /admin/foods', () {
    test('admin melihat makanan lintas toko', () async {
      await fixture.food(merchantToken);

      final response =
          await api.request('GET', '/admin/foods', token: adminToken);
      expect(response.statusCode, 200);

      final body = await api.json(response);
      expect((body['foods'] as List), isNotEmpty);
      expect(body['total'], isA<int>());
      // Nama toko ikut supaya admin tahu milik siapa.
      expect(((body['foods'] as List).first as Map)['merchantName'],
          isA<String>());
    });

    test('filter ?active=false', () async {
      final body = await api.json(
        await api.request('GET', '/admin/foods?active=false', token: adminToken),
      );
      expect(body['foods'], isEmpty);
    });

    test('buyer â†’ 403', () async {
      expect(
        (await api.request('GET', '/admin/foods', token: buyerToken)).statusCode,
        403,
      );
    });
  });

  group('GET /admin/orders', () {
    test('admin melihat semua pesanan', () async {
      final foodId = await fixture.food(merchantToken);
      await api.request('POST', '/orders', token: buyerToken, body: {
        'foodId': foodId,
        'quantity': 1,
      });

      final response =
          await api.request('GET', '/admin/orders', token: adminToken);
      expect(response.statusCode, 200);

      final body = await api.json(response);
      expect((body['orders'] as List), hasLength(1));
      expect(((body['orders'] as List).first as Map)['buyerName'], isA<String>());
    });

    test('filter ?status=pending', () async {
      final body = await api.json(
        await api.request('GET', '/admin/orders?status=pending',
            token: adminToken),
      );
      expect(body['orders'], isEmpty);
    });

    test('status tak dikenal â†’ 422', () async {
      expect(
        (await api.request('GET', '/admin/orders?status=ngawur',
                token: adminToken))
            .statusCode,
        422,
      );
    });
  });

  group('GET /admin/stats', () {
    test('memuat jumlah akun ditangguhkan dan porsi terselamatkan', () async {
      final body = await api.json(
        await api.request('GET', '/admin/stats', token: adminToken),
      );

      expect((body['users'] as Map)['suspended'], 0);
      expect((body['orders'] as Map)['portionsSaved'], isA<int>());
    });
  });

  group('GET /admin/users?q=', () {
    test('mencari berdasarkan email', () async {
      final body = await api.json(
        await api.request('GET', '/admin/users?q=buyer@', token: adminToken),
      );
      expect((body['users'] as List), hasLength(1));
    });

    test('pencarian tanpa hasil mengembalikan daftar kosong', () async {
      final body = await api.json(
        await api.request('GET', '/admin/users?q=tidakada', token: adminToken),
      );
      expect(body['users'], isEmpty);
      expect(body['total'], 0);
    });
  });
}
