// P7: Unit test 3 advanced feature (Autentikasi, Lokasi, Kamera).
//
// Semua memakai mock/fake sehingga tidak butuh izin perangkat atau internet.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_rescue_app/core/network/api_client.dart';
import 'package:food_rescue_app/core/network/api_exception.dart';
import 'package:food_rescue_app/models/user_role.dart';
import 'package:food_rescue_app/providers/camera_provider.dart';
import 'package:food_rescue_app/providers/location_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';

http.Response _json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

/// Kontrak backend sendiri: `{"token": "...", "user": {...}}`.
Map<String, dynamic> _loginBody() => {
      'token': 'token-abc',
      'user': {
        'id': 7,
        'name': 'Emily Johnson',
        'email': 'emily@foodrescue.id',
        'role': 'buyer',
      },
    };

ApiAuthRepository _repo(MockClient client) => ApiAuthRepository(
      api: ApiClient(client: client, baseUrl: 'http://test.local'),
    );

void main() {
  group('Advanced Feature #1 — Autentikasi', () {
    test('login sukses mengembalikan AuthUser lengkap', () async {
      final repo = _repo(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/login');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'emily@foodrescue.id');
          return _json(_loginBody());
        }),
      );

      final user =
          await repo.login(email: 'emily@foodrescue.id', password: 'rahasia12');

      expect(user.id, 7);
      expect(user.name, 'Emily Johnson');
      expect(user.email, 'emily@foodrescue.id');
      expect(user.role, UserRole.buyer);
      expect(user.token, 'token-abc');
    });

    test('password salah (HTTP 401) -> ApiException dengan pesan server',
        () async {
      final repo = _repo(
        MockClient((_) async => _json({
              'error': {'code': 'invalid_credentials', 'message': 'Password salah.'}
            }, 401)),
      );

      await expectLater(
        repo.login(email: 'emily@foodrescue.id', password: 'salah'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Password salah.')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('token tidak ada di respons -> ApiException', () async {
      final body = _loginBody()..remove('token');
      final repo = _repo(MockClient((_) async => _json(body)));

      await expectLater(
        repo.login(email: 'emily@foodrescue.id', password: 'rahasia12'),
        throwsA(isA<ApiException>()),
      );
    });

    test('jaringan mati -> ApiException (statusCode null)', () async {
      final repo = _repo(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        repo.login(email: 'emily@foodrescue.id', password: 'rahasia12'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', null),
        ),
      );
    });

    test('me() dengan 401 mengembalikan null, bukan melempar', () async {
      final repo = _repo(
        MockClient((_) async => _json({
              'error': {'code': 'unauthorized', 'message': 'Token tidak valid.'}
            }, 401)),
      );

      expect(await repo.me('token-lama'), isNull);
    });

    test('me() memulihkan sesi dari token', () async {
      final repo = _repo(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token-abc');
          return _json({'user': _loginBody()['user']});
        }),
      );

      final user = await repo.me('token-abc');

      expect(user, isNotNull);
      expect(user!.id, 7);
      expect(user.token, 'token-abc');
    });
  });


  group('Advanced Feature #2 — Lokasi (izin & pembatalan)', () {
    test('izin ditolak -> status denied, bukan crash', () async {
      final repo = _FakeLocationRepo(
        const LocationResult(
          permission: LocationPermissionState.denied,
          errorMessage: 'Izin lokasi ditolak.',
        ),
      );

      final result = await repo.getCurrentPosition();

      expect(result.permission, LocationPermissionState.denied);
      expect(result.hasPosition, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('GPS mati -> serviceDisabled', () async {
      final repo = _FakeLocationRepo(
        const LocationResult(
          permission: LocationPermissionState.serviceDisabled,
          errorMessage: 'GPS belum aktif.',
        ),
      );

      final result = await repo.getCurrentPosition();

      expect(result.permission, LocationPermissionState.serviceDisabled);
    });

    test('izin ditolak permanen -> deniedForever (butuh Settings)', () async {
      final repo = _FakeLocationRepo(
        const LocationResult(
          permission: LocationPermissionState.deniedForever,
          errorMessage: 'Diblokir permanen.',
        ),
      );

      final result = await repo.getCurrentPosition();

      expect(result.permission, LocationPermissionState.deniedForever);
    });
  });

  group('Advanced Feature #3 — Kamera (izin & pembatalan)', () {
    test('user membatalkan kamera -> cancelled, bukan error', () async {
      final repo = _FakeCameraRepo(const CameraResult(cancelled: true));

      final result = await repo.takePhoto();

      expect(result.cancelled, isTrue);
      expect(result.hasPhoto, isFalse);
      expect(result.errorMessage, isNull);
    });

    test('izin kamera ditolak -> ada pesan error yang jelas', () async {
      final repo = _FakeCameraRepo(
        const CameraResult(errorMessage: 'Tidak bisa membuka kamera: denied'),
      );

      final result = await repo.takePhoto();

      expect(result.hasPhoto, isFalse);
      expect(result.cancelled, isFalse);
      expect(result.errorMessage, contains('kamera'));
    });

    test('foto berhasil diambil -> bytes tersedia', () async {
      final repo = _FakeCameraRepo(
        CameraResult(bytes: Uint8List.fromList([1, 2, 3, 4])),
      );

      final result = await repo.takePhoto();

      expect(result.hasPhoto, isTrue);
      expect(result.bytes, hasLength(4));
    });
  });
}

/// Fake repository lokasi (mewakili kondisi izin tanpa menyentuh perangkat).
class _FakeLocationRepo implements LocationRepository {
  _FakeLocationRepo(this._result);
  final LocationResult _result;

  @override
  Future<LocationResult> getCurrentPosition() async => _result;

  @override
  Future<bool> openAppSettings() async => true;
}

/// Fake repository kamera.
class _FakeCameraRepo implements CameraRepository {
  _FakeCameraRepo(this._result);
  final CameraResult _result;

  @override
  Future<CameraResult> takePhoto() async => _result;
}
