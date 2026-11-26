import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  configureDriftForTests();
  late TestApi api;
  late String token;

  setUp(() async {
    api = TestApi();
    (token, _, _) = await registerAndLogin(api);
  });
  tearDown(() => api.close());

  Future<Response> change({
    required String current,
    required String next,
    String? withToken,
  }) =>
      api.request(
        'POST',
        '/auth/change-password',
        token: withToken ?? token,
        body: {'currentPassword': current, 'newPassword': next},
      );

  group('POST /auth/change-password', () {
    test('password lama benar → 200 dan password baru berlaku', () async {
      expect(
        (await change(current: 'PasswordKuat123', next: 'PasswordBaru456'))
            .statusCode,
        200,
      );

      expect(
        (await api.request('POST', '/auth/login', body: {
          'email': 'buyer@example.com',
          'password': 'PasswordBaru456',
        }))
            .statusCode,
        200,
      );
    });

    test('password lama salah → 422 wrong_password', () async {
      final response = await change(current: 'Salah123456', next: 'PasswordBaru456');
      expect(response.statusCode, 422);

      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'wrong_password');
    });

    test('password lama salah tidak mengubah apa pun', () async {
      await change(current: 'Salah123456', next: 'PasswordBaru456');

      expect(
        (await api.request('POST', '/auth/login', body: {
          'email': 'buyer@example.com',
          'password': 'PasswordKuat123',
        }))
            .statusCode,
        200,
      );
    });

    test('password baru terlalu pendek → 422', () async {
      final response = await change(current: 'PasswordKuat123', next: 'pendek');
      expect(response.statusCode, 422);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'invalid_password');
    });

    test('password sama dengan lama ditolak', () async {
      final response =
          await change(current: 'PasswordKuat123', next: 'PasswordKuat123');
      expect(response.statusCode, 422);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'same_password');
    });

    test('tanpa token → 401', () async {
      expect(
        (await api.request('POST', '/auth/change-password', body: {
          'currentPassword': 'PasswordKuat123',
          'newPassword': 'PasswordBaru456',
        }))
            .statusCode,
        401,
      );
    });

    test('respons tidak memuat hash password', () async {
      final response =
          await change(current: 'PasswordKuat123', next: 'PasswordBaru456');
      expect((await response.readAsString()).contains(r'$2a$'), isFalse);
    });
  });
}
