// P7: Unit test 3 advanced feature (Autentikasi, Lokasi, Kamera).
//
// Semua memakai mock/fake sehingga tidak butuh izin perangkat atau internet.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_rescue_app/providers/camera_provider.dart';
import 'package:food_rescue_app/providers/location_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';

http.Response _json(Object body, [int status = 200]) {
  return http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

Map<String, dynamic> _loginBody() => {
      'id': 1,
      'username': 'emilys',
      'email': 'emily.johnson@x.dummyjson.com',
      'firstName': 'Emily',
      'lastName': 'Johnson',
      'image': 'https://dummyjson.com/icon/emilys/128',
      'accessToken': 'token-abc',
    };

void main() {
  group('Advanced Feature #1 — Autentikasi', () {
    test('login sukses mengembalikan AuthUser lengkap', () async {
      final repo = ApiAuthRepository(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], 'emilys');
          return _json(_loginBody());
        }),
      );

      final user = await repo.login(username: 'emilys', password: 'emilyspass');

      expect(user.id, 1);
      expect(user.name, 'Emily Johnson');
      expect(user.email, 'emily.johnson@x.dummyjson.com');
      expect(user.token, 'token-abc');
    });

    test('password salah (HTTP 400) -> AuthException', () async {
      final repo = ApiAuthRepository(
        client: MockClient((_) async => _json({'message': 'Invalid credentials'}, 400)),
      );

      expect(
        () => repo.login(username: 'emilys', password: 'salah'),
        throwsA(isA<AuthException>()),
      );
    });

    test('token tidak ada di respons -> AuthException', () async {
      final body = _loginBody()..remove('accessToken');
      final repo = ApiAuthRepository(
        client: MockClient((_) async => _json(body)),
      );

      expect(
        () => repo.login(username: 'emilys', password: 'x'),
        throwsA(isA<AuthException>()),
      );
    });

    test('jaringan mati -> AuthException', () async {
      final repo = ApiAuthRepository(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );

      expect(
        () => repo.login(username: 'emilys', password: 'x'),
        throwsA(isA<AuthException>()),
      );
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
