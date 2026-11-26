import 'package:food_rescue_backend/db/database.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  configureDriftForTests();

  late TestApi api;
  late String token;
  late Map<String, dynamic> user;

  setUp(() async {
    api = TestApi();
    (token, user, _) = await registerAndLogin(
      api,
      email: 'profil@example.com',
      name: 'Budi Santoso',
    );
  });
  tearDown(() => api.close());

  group('PATCH /auth/me', () {
    test('ubah nama saja', () async {
      final response = await api.request(
        'PATCH',
        '/auth/me',
        token: token,
        body: {'name': 'Budi S.'},
      );

      expect(response.statusCode, 200);
      final body = await api.json(response);
      final updated = body['user'] as Map<String, dynamic>;

      expect(updated['name'], 'Budi S.');
      expect(updated['email'], user['email'], reason: 'email tidak berubah');
      expect(updated['role'], user['role'], reason: 'role tidak berubah');
      expect(updated['id'], user['id']);
    });

    test('ubah email saja, dinormalisasi lowercase', () async {
      final response = await api.request(
        'PATCH',
        '/auth/me',
        token: token,
        body: {'email': '  Budi.Baru@Example.COM '},
      );

      final updated = (await api.json(response))['user'] as Map;
      expect(updated['email'], 'budi.baru@example.com');
      expect(updated['name'], 'Budi Santoso');
    });

    test('email bentrok dengan akun lain → 409', () async {
      await registerAndLogin(api, email: 'lain@example.com');

      final response = await api.request(
        'PATCH',
        '/auth/me',
        token: token,
        body: {'email': 'lain@example.com'},
      );
      expect(response.statusCode, 409);
    });

    test('email tidak valid → 422', () async {
      for (final email in ['bukanemail', 'a@b', '@x.co']) {
        final response = await api.request(
          'PATCH',
          '/auth/me',
          token: token,
          body: {'email': email},
        );
        expect(response.statusCode, 422, reason: email);
      }
    });

    test('role dan password ditolak 422, data tidak berubah', () async {
      final response = await api.request(
        'PATCH',
        '/auth/me',
        token: token,
        body: {'name': 'Baru', 'role': 'admin', 'password': 'Hacked123'},
      );

      expect(response.statusCode, 422);
      final body = await api.json(response);
      expect(
        (body['error'] as Map)['code'],
        'immutable_field',
        reason: 'klien harus tahu field-nya ditolak, bukan diabaikan',
      );

      final row = await (api.db.select(api.db.users)
            ..where((t) => t.id.equals(user['id'] as int)))
          .getSingle();

      expect(row.role, UserRole.buyer, reason: 'role harus tetap buyer');
      expect(row.name, 'Budi Santoso', reason: 'tidak ada perubahan sebagian');
      // Password lama tetap berlaku.
      expect(
        api.hasher.verify('PasswordKuat123', row.passwordHash),
        isTrue,
      );
      expect(api.hasher.verify('Hacked123', row.passwordHash), isFalse);
    });

    test('tanpa token → 401', () async {
      final response =
          await api.request('PATCH', '/auth/me', body: {'name': 'X'});
      expect(response.statusCode, 401);
    });

    test('body kosong → data tidak berubah (bukan error)', () async {
      final response =
          await api.request('PATCH', '/auth/me', token: token, body: {});

      expect(response.statusCode, 200);
      final updated = (await api.json(response))['user'] as Map;
      expect(updated['name'], 'Budi Santoso');
    });

    test('login berikutnya memakai email baru', () async {
      await api.request(
        'PATCH',
        '/auth/me',
        token: token,
        body: {'email': 'baru@example.com'},
      );

      expect(
        (await api.request('POST', '/auth/login', body: {
          'email': 'baru@example.com',
          'password': 'PasswordKuat123',
        }))
            .statusCode,
        200,
      );
      expect(
        (await api.request('POST', '/auth/login', body: {
          'email': 'profil@example.com',
          'password': 'PasswordKuat123',
        }))
            .statusCode,
        401,
      );
    });
  });
}
