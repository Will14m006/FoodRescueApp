import 'dart:convert';

import 'package:food_rescue_backend/auth/auth_middleware.dart';
import 'package:food_rescue_backend/db/database.dart';
import 'package:food_rescue_backend/middleware/api_response.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

const _password = 'PasswordKuat123';

void main() {
  late TestApi api;

  setUp(() => api = TestApi());
  tearDown(() => api.close());

  group('POST /auth/register', () {
    test('201 + token + user tanpa passwordHash', () async {
      final response = await api.request('POST', '/auth/register', body: {
        'email': 'budi@example.com',
        'password': _password,
        'name': 'Budi',
      });

      expect(response.statusCode, 201);
      final body = await api.json(response);
      final user = body['user'] as Map<String, dynamic>;

      expect(body['token'], isA<String>());
      expect(body['tokenType'], 'Bearer');
      expect(body['expiresIn'], 3600);
      expect(user['email'], 'budi@example.com');
      expect(user['role'], 'buyer');

      // Kunci: hash tidak pernah ikut keluar.
      expect(body.toString().toLowerCase().contains('passwordhash'), isFalse);
      expect(body.toString().contains(r'$2a$'), isFalse);
    });

    test('email dinormalisasi ke huruf kecil', () async {
      final response = await api.request('POST', '/auth/register', body: {
        'email': '  Budi@Example.COM ',
        'password': _password,
        'name': 'Budi',
      });

      final body = await api.json(response);
      expect((body['user'] as Map)['email'], 'budi@example.com');
    });

    test('password disimpan sebagai hash bcrypt, bukan teks asli', () async {
      await registerAndLogin(api, email: 'hash@example.com', password: _password);

      final row = await api.db.select(api.db.users).getSingle();
      expect(row.passwordHash, startsWith(r'$2a$'));
      expect(row.passwordHash.contains(_password), isFalse);
      expect(api.hasher.verify(_password, row.passwordHash), isTrue);
    });

    test('email duplikat → 409', () async {
      await registerAndLogin(api, email: 'dobel@example.com');

      final response = await api.request('POST', '/auth/register', body: {
        'email': 'DOBEL@example.com', // beda kapital, harus tetap bentrok
        'password': _password,
        'name': 'Lain',
      });

      expect(response.statusCode, 409);
    });

    test('role merchant diizinkan', () async {
      final response = await api.request('POST', '/auth/register', body: {
        'email': 'toko@example.com',
        'password': _password,
        'name': 'Toko',
        'role': 'merchant',
      });

      final body = await api.json(response);
      expect((body['user'] as Map)['role'], 'merchant');
    });

    test('role admin DITOLAK lewat HTTP → 403', () async {
      final response = await api.request('POST', '/auth/register', body: {
        'email': 'admin@example.com',
        'password': _password,
        'name': 'Ngeyel',
        'role': 'admin',
      });

      expect(response.statusCode, 403);
      expect(await api.db.select(api.db.users).get(), isEmpty);
    });

    test('role asal-asalan → 422', () async {
      final response = await api.request('POST', '/auth/register', body: {
        'email': 'x@example.com',
        'password': _password,
        'name': 'X',
        'role': 'superuser',
      });
      expect(response.statusCode, 422);
    });

    group('validasi input', () {
      test('email tidak valid → 422', () async {
        for (final email in ['bukanemail', 'a@b', '@b.co', 'a@.co', 'a b@c.co']) {
          final response = await api.request('POST', '/auth/register', body: {
            'email': email,
            'password': _password,
            'name': 'X',
          });
          expect(response.statusCode, 422, reason: 'email "$email"');
        }
      });

      test('password terlalu pendek → 422', () async {
        final response = await api.request('POST', '/auth/register', body: {
          'email': 'x@example.com',
          'password': 'pendek',
          'name': 'X',
        });
        expect(response.statusCode, 422);
      });

      test('password > 72 byte → 422 (bukan dipotong diam-diam)', () async {
        final response = await api.request('POST', '/auth/register', body: {
          'email': 'x@example.com',
          'password': List.filled(73, 'a').join(),
          'name': 'X',
        });
        expect(response.statusCode, 422);
      });

      test('password 72 byte diterima', () async {
        final response = await api.request('POST', '/auth/register', body: {
          'email': 'x@example.com',
          'password': List.filled(72, 'a').join(),
          'name': 'X',
        });
        expect(response.statusCode, 201);
      });

      test('password multibyte dihitung per byte', () async {
        // 30 karakter emoji = 120 byte > 72 → ditolak.
        final response = await api.request('POST', '/auth/register', body: {
          'email': 'x@example.com',
          'password': List.filled(30, '🔐').join(),
          'name': 'X',
        });
        expect(response.statusCode, 422);
      });

      test('field wajib kosong → 422', () async {
        for (final body in [
          <String, dynamic>{'password': _password, 'name': 'X'},
          <String, dynamic>{'email': 'x@example.com', 'name': 'X'},
          <String, dynamic>{'email': 'x@example.com', 'password': _password},
        ]) {
          final response = await api.request('POST', '/auth/register', body: body);
          expect(response.statusCode, 422, reason: body.keys.join(','));
        }
      });

      test('body bukan objek JSON → 400', () async {
        final response = await api.request(
          'POST',
          '/auth/register',
          body: ['a'],
        );
        expect(response.statusCode, 400);
      });

      test('Content-Type salah → 415', () async {
        final response = await api.request(
          'POST',
          '/auth/register',
          headers: {'content-type': 'text/plain'},
        );
        expect(response.statusCode, 415);
      });

      test('body melebihi 8 KB → 413', () async {
        final response = await api.request('POST', '/auth/register', body: {
          'email': 'x@example.com',
          'password': _password,
          'name': 'n' * 9000,
        });
        expect(response.statusCode, 413);
      });
    });
  });

  group('POST /auth/login', () {
    setUp(() async {
      await registerAndLogin(api, email: 'login@example.com', password: _password);
    });

    test('kredensial benar → 200 + token baru', () async {
      final response = await api.request('POST', '/auth/login', body: {
        'email': 'login@example.com',
        'password': _password,
      });

      expect(response.statusCode, 200);
      final body = await api.json(response);
      expect(body['token'], isA<String>());
      expect(api.jwt.verify(body['token'] as String), isNotNull);
    });

    test('password salah → 401', () async {
      final response = await api.request('POST', '/auth/login', body: {
        'email': 'login@example.com',
        'password': 'PasswordSalah999',
      });
      expect(response.statusCode, 401);
    });

    test('email tidak terdaftar → 401 dengan pesan IDENTIK', () async {
      final salahPassword = await api.json(
        await api.request('POST', '/auth/login', body: {
          'email': 'login@example.com',
          'password': 'PasswordSalah999',
        }),
      );
      final emailAsing = await api.json(
        await api.request('POST', '/auth/login', body: {
          'email': 'tidak-ada@example.com',
          'password': 'PasswordSalah999',
        }),
      );

      // Pesan sama → tidak bisa dipakai menebak email mana yang terdaftar.
      expect(
        (salahPassword['error'] as Map)['message'],
        (emailAsing['error'] as Map)['message'],
      );
    });

    test('terlalu banyak percobaan → 429', () async {
      // Default maxAttempts = 5.
      for (var i = 0; i < 5; i++) {
        final response = await api.request('POST', '/auth/login', body: {
          'email': 'login@example.com',
          'password': 'salah$i',
        });
        expect(response.statusCode, 401);
      }

      final response = await api.request('POST', '/auth/login', body: {
        'email': 'login@example.com',
        'password': _password,
      });
      expect(response.statusCode, 429);

      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'too_many_attempts');
    });

    test('login berhasil menghapus hitungan gagal', () async {
      await api.request('POST', '/auth/login', body: {
        'email': 'login@example.com',
        'password': 'salah',
      });
      await api.request('POST', '/auth/login', body: {
        'email': 'login@example.com',
        'password': _password,
      });

      // Setelah reset, jatah percobaan kembali penuh.
      for (var i = 0; i < 5; i++) {
        final response = await api.request('POST', '/auth/login', body: {
          'email': 'login@example.com',
          'password': 'salah$i',
        });
        expect(response.statusCode, 401);
      }
    });
  });

  group('GET /auth/me', () {
    test('token sah → data user sendiri', () async {
      final (token, user, _) = await registerAndLogin(api);

      final response = await api.request('GET', '/auth/me', token: token);
      expect(response.statusCode, 200);

      final body = await api.json(response);
      expect((body['user'] as Map)['id'], user['id']);
      expect(body.toString().toLowerCase().contains('passwordhash'), isFalse);
    });

    test('tanpa header Authorization → 401 + www-authenticate', () async {
      final response = await api.request('GET', '/auth/me');
      expect(response.statusCode, 401);
      expect(response.headers['www-authenticate'], 'Bearer');
    });

    test('token sampah → 401', () async {
      final response = await api.request(
        'GET',
        '/auth/me',
        token: 'sampah.sampah.sampah',
      );
      expect(response.statusCode, 401);
    });

    test('skema selain Bearer → 401', () async {
      final (token, _, _) = await registerAndLogin(api);

      final response = await api.request('GET', '/auth/me', headers: {
        'authorization': 'Basic $token',
      });
      expect(response.statusCode, 401);
    });
  });

  group('authGuard — role', () {
    /// Rute contoh yang hanya boleh dibuka merchant/admin.
    late Handler merchantOnly;

    setUp(() {
      merchantOnly = const Pipeline().addMiddleware(
        authGuard(api.jwt, roles: {UserRole.merchant, UserRole.admin}),
      ).addHandler((Request request) {
        final user = authenticatedUser(request);
        return ApiResponse.ok({'ok': true, 'role': user.role.name});
      });
    });

    Future<Response> call(String? token) async => merchantOnly(Request(
          'GET',
          Uri.parse('http://localhost/kasir'),
          headers: token == null ? null : {'authorization': 'Bearer $token'},
        ));

    test('token buyer di rute merchant → 403', () async {
      final (token, _, _) = await registerAndLogin(api);
      expect((await call(token)).statusCode, 403);
    });

    test('token merchant → 200', () async {
      final (token, _, _) = await registerAndLogin(
        api,
        email: 'toko@example.com',
        role: 'merchant',
      );
      expect((await call(token)).statusCode, 200);
    });

    test('tanpa token → 401, bukan 403', () async {
      expect((await call(null)).statusCode, 401);
    });

    test('role buyer tidak bisa naik jadi merchant dengan mengubah claim', () async {
      final (token, _, _) = await registerAndLogin(api);

      // Ambil token buyer, ganti payload role → tanda tangan tidak cocok.
      final parts = token.split('.');
      final payload = base64UrlEncode(
        '{"sub":"1","role":"merchant","exp":9999999999,'
                '"iss":"food-rescue-api"}'
            .codeUnits,
      ).replaceAll('=', '');
      final forged = '${parts[0]}.$payload.${parts[2]}';

      expect((await call(forged)).statusCode, 401);
    });
  });

  group('kebocoran data', () {
    test('password TIDAK pernah muncul di log server', () async {
      await registerAndLogin(api, email: 'log@example.com', password: _password);
      await api.request('POST', '/auth/login', body: {
        'email': 'log@example.com',
        'password': _password,
      });
      await api.request('POST', '/auth/login', body: {
        'email': 'log@example.com',
        'password': 'PasswordSalah999',
      });

      final joined = api.logs.join('\n');
      expect(joined.contains(_password), isFalse);
      expect(joined.contains('PasswordSalah999'), isFalse);
      // logRequests bawaan shelf tidak mencatat body maupun header auth.
      expect(joined.toLowerCase().contains('authorization'), isFalse);
    });

    test('token tidak muncul di log', () async {
      final (token, _, _) = await registerAndLogin(api);
      await api.request('GET', '/auth/me', token: token);

      expect(api.logs.join('\n').contains(token), isFalse);
    });

    test('hash tidak pernah ikut di respons apa pun', () async {
      final (token, _, registerBody) = await registerAndLogin(api);

      final meBody = await api.json(
        await api.request('GET', '/auth/me', token: token),
      );

      for (final body in [registerBody, meBody]) {
        expect(body.toString().contains(r'$2a$'), isFalse);
      }
    });
  });
}
