// P9: test untuk hasil refactor — pemisahan tanggung jawab.
//
// 1. `Validators`        : aturan input, tanpa widget      (unit test)
// 2. `Formatters`        : format Rupiah & tanggal         (unit test)
// 3. `ProfileRepository` : request `PATCH /auth/me`        (MockClient)
// 4. `ProfileFormScreen` : input + status UI saja          (widget test)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_rescue_app/core/network/api_client.dart';
import 'package:food_rescue_app/core/network/api_exception.dart';
import 'package:food_rescue_app/core/utils/formatters.dart';
import 'package:food_rescue_app/core/validation/validators.dart';
import 'package:food_rescue_app/models/user_role.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/profile_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/profile_repository.dart';
import 'package:food_rescue_app/screens/profile_form_screen.dart';

import 'support/fakes.dart';

const _user = AuthUser(
  id: 1,
  name: 'William She',
  email: 'william@test.com',
  role: UserRole.buyer,
  token: 'token-lama',
);

ApiProfileRepository _repo(MockClient client) => ApiProfileRepository(
      api: ApiClient(client: client, baseUrl: 'http://test.local'),
    );

void main() {
  group('Validators — aturan input', () {
    test('required: kosong & hanya spasi ditolak', () {
      expect(Validators.required(null, 'Email'), 'Email wajib diisi.');
      expect(Validators.required('   ', 'Email'), 'Email wajib diisi.');
      expect(Validators.required('a', 'Email'), isNull);
    });

    test('minLength: di bawah batas ditolak, pas batas diterima', () {
      expect(Validators.minLength('abc', label: 'Password', min: 6),
          'Password minimal 6 karakter.');
      expect(Validators.minLength('abcdef', label: 'Password', min: 6), isNull);
    });

    test('email: format salah ditolak', () {
      expect(Validators.email('bukan-email'), 'Format email tidak valid.');
      expect(Validators.email('a@b'), 'Format email tidak valid.');
      expect(Validators.email('william@test.com'), isNull);
    });

    test('quantity: bukan angka / di luar rentang ditolak', () {
      expect(Validators.quantity('abc', min: 1, max: 4),
          'Jumlah harus berupa angka.');
      expect(Validators.quantity('0', min: 1, max: 4), 'Minimal 1.');
      expect(Validators.quantity('9', min: 1, max: 4),
          'Melebihi batas maksimal (4).');
      expect(Validators.quantity('2', min: 1, max: 4), isNull);
    });
  });

  group('Formatters — satu format Rupiah untuk seluruh app', () {
    test('rupiah memberi pemisah ribuan', () {
      expect(Formatters.rupiah(0), 'Rp 0');
      expect(Formatters.rupiah(15000), 'Rp 15.000');
      expect(Formatters.rupiah(1234567), 'Rp 1.234.567');
    });

    test('dateTime selalu 2 digit jam & menit', () {
      expect(Formatters.dateTime(DateTime(2026, 5, 7, 9, 5)),
          '7/5/2026 • 09:05 WIB');
    });
  });

  group('ApiProfileRepository — PATCH /auth/me', () {
    test('sukses: hanya nama & email dikirim, token lama dipertahankan',
        () async {
      late http.Request sent;

      final repo = _repo(MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'user': {
              'id': 1,
              'name': 'Budi Santoso',
              'email': 'budi@test.com',
              'role': 'buyer',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      final updated = await repo.updateProfile(
        current: _user,
        name: 'Budi Santoso',
        email: 'budi@test.com',
      );

      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/auth/me');
      expect(sent.headers['Authorization'], 'Bearer token-lama');
      expect(jsonDecode(sent.body), {
        'name': 'Budi Santoso',
        'email': 'budi@test.com',
      });

      expect(updated.name, 'Budi Santoso');
      expect(updated.email, 'budi@test.com');
      expect(updated.token, 'token-lama');
      expect(updated.id, 1);
      // Role tidak bisa diubah lewat endpoint ini.
      expect(updated.role, UserRole.buyer);
    });

    test('email sudah dipakai (409) -> ApiException dengan pesan server',
        () async {
      final repo = _repo(MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'code': 'email_taken', 'message': 'Email sudah dipakai.'}
            }),
            409,
            headers: {'content-type': 'application/json'},
          )));

      await expectLater(
        repo.updateProfile(
          current: _user,
          name: 'Budi',
          email: 'dipakai@test.com',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Email sudah dipakai.',
        )),
      );
    });

    test('HTTP 500 -> ApiException', () async {
      final repo = _repo(
        MockClient((_) async => http.Response('boom', 500)),
      );

      await expectLater(
        repo.updateProfile(
          current: _user,
          name: 'Budi',
          email: 'budi@test.com',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('koneksi gagal -> ApiException tanpa statusCode', () async {
      final repo = _repo(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        repo.updateProfile(
          current: _user,
          name: 'Budi',
          email: 'budi@test.com',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', null),
        ),
      );
    });
  });

  group('ApiClient — satu pintu keluar HTTP', () {
    test('body bukan JSON -> ApiException', () async {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('<html>', 200)),
        baseUrl: 'http://test.local',
      );

      await expectLater(
        api.request(method: 'GET', path: '/foods'),
        throwsA(isA<ApiException>()),
      );
    });

    test('204 tanpa body dianggap objek kosong (bukan error)', () async {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('', 204)),
        baseUrl: 'http://test.local',
      );

      expect(await api.request(method: 'GET', path: '/x'), isEmpty);
    });

    test('token dikirim sebagai Bearer, query di-encode', () async {
      late Uri uri;
      late String? auth;

      final api = ApiClient(
        client: MockClient((request) async {
          uri = request.url;
          auth = request.headers['Authorization'];
          return http.Response('{}', 200);
        }),
        baseUrl: 'http://test.local',
      );

      await api.request(
        method: 'GET',
        path: '/admin/users',
        token: 'tkn',
        query: {'role': 'merchant', 'limit': '200'},
      );

      expect(auth, 'Bearer tkn');
      expect(uri.queryParameters, {'role': 'merchant', 'limit': '200'});
    });
  });

  group('ProfileFormScreen — input & status UI', () {
    testWidgets('field terisi data sesi, validasi jalan sebelum kirim',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider
              .overrideWithValue(await useInMemorySession(user: _user)),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrap(const ProfileFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      String textAt(int index) => tester
          .widget<EditableText>(find.byType(EditableText).at(index))
          .controller
          .text;

      // Hanya dua field: nama dan email.
      expect(find.byType(EditableText), findsNWidgets(2));
      expect(textAt(0), 'William She');
      expect(textAt(1), 'william@test.com');

      // Kosongkan email -> validasi menolak, tidak ada request.
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
    });

    testWidgets('simpan berhasil: sesi diperbarui', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider
              .overrideWithValue(await useInMemorySession(user: _user)),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrap(const ProfileFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Budi Santoso');
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      final user = container.read(authProvider).valueOrNull;
      expect(user?.name, 'Budi Santoso');
      expect(user?.email, 'william@test.com');
      // Token tetap sama setelah edit profil.
      expect(user?.token, 'token-lama');
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: const Size(800, 1400)),
      child: widget!,
    ),
  );
}

/// Fake: UI test tidak boleh menyentuh HTTP.
class _FakeProfileRepo implements ProfileRepository {
  @override
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String name,
    required String email,
  }) async {
    return AuthUser(
      id: current.id,
      name: name,
      email: email,
      role: current.role,
      token: current.token,
    );
  }
}

