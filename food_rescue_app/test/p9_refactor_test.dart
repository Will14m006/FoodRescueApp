// P9: test untuk hasil refactor — pemisahan tanggung jawab.
//
// 1. `Validators`  : aturan input, tanpa widget    (unit test)
// 2. `Formatters`  : format Rupiah & tanggal       (unit test)
// 3. `ProfileRepository` : request API             (MockClient, tanpa internet)
// 4. `ProfileForm` : input + status UI saja        (widget test)
//
// Widget test hanya membuktikan UI bereaksi (loading -> sukses/gagal); aturan
// validasi & pemanggilan API sudah diuji terpisah di atas.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:food_rescue_app/core/network/api_client.dart';
import 'package:food_rescue_app/core/utils/formatters.dart';
import 'package:food_rescue_app/core/validation/validators.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/profile_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/profile_repository.dart';
import 'package:food_rescue_app/screens/profile_form_screen.dart';

const _user = AuthUser(
  id: 1,
  name: 'William She',
  email: 'william@test.com',
  token: 'token-lama',
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

  group('ApiProfileRepository — request API', () {
    test('sukses: PUT ke /users/{id}, data server dipakai', () async {
      late http.Request sent;

      final repo = ApiProfileRepository(
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'id': 1,
              'firstName': 'Budi',
              'lastName': 'Santoso',
              'email': 'budi@test.com',
            }),
            200,
          );
        }),
      );

      final updated = await repo.updateProfile(
        current: _user,
        firstName: 'Budi',
        lastName: 'Santoso',
        email: 'budi@test.com',
      );

      expect(sent.method, 'PUT');
      expect(sent.url.toString(), 'https://dummyjson.com/users/1');
      expect(jsonDecode(sent.body), {
        'firstName': 'Budi',
        'lastName': 'Santoso',
        'email': 'budi@test.com',
      });

      expect(updated.name, 'Budi Santoso');
      expect(updated.email, 'budi@test.com');
      // Token & id sesi berjalan tidak boleh hilang.
      expect(updated.token, 'token-lama');
      expect(updated.id, 1);
    });

    test('HTTP 500 -> AuthException', () async {
      final repo = ApiProfileRepository(
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      expect(
        () => repo.updateProfile(
          current: _user,
          firstName: 'Budi',
          lastName: 'Santoso',
          email: 'budi@test.com',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('koneksi gagal -> AuthException', () async {
      final repo = ApiProfileRepository(
        client: MockClient((_) async => throw Exception('offline')),
      );

      expect(
        () => repo.updateProfile(
          current: _user,
          firstName: 'Budi',
          lastName: 'Santoso',
          email: 'budi@test.com',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('ApiClient — dipakai bersama auth/order/profil', () {
    test('body bukan JSON -> error lewat onError', () async {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('<html>', 200)),
      );

      expect(
        () => api.sendJson(
          method: 'POST',
          endpoint: 'https://contoh.test/x',
          body: const {},
          onError: (message, statusCode) => Exception(message),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ProfileFormScreen — input & status UI', () {
    testWidgets('field terisi data sesi, validasi jalan sebelum kirim',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authProvider.notifier).replaceUser(_user);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrap(const ProfileFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Prefill dari sesi berjalan.
      String textAt(int index) =>
          tester.widget<EditableText>(find.byType(EditableText).at(index))
              .controller
              .text;

      expect(textAt(0), 'William');
      expect(textAt(1), 'She');
      expect(textAt(2), 'william@test.com');

      // Kosongkan email -> validasi menolak, tidak ada request.
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
    });

    testWidgets('simpan berhasil: state user diganti', (tester) async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authProvider.notifier).replaceUser(_user);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrap(const ProfileFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      final user = container.read(authProvider).valueOrNull;
      expect(user?.name, 'William She');
      expect(user?.email, 'william@test.com');
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: const Size(800, 1400),
      ),
      child: widget!,
    ),
  );
}

/// Fake: UI test tidak boleh menyentuh HTTP.
class _FakeProfileRepo implements ProfileRepository {
  @override
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    return AuthUser(
      id: current.id,
      name: '$firstName $lastName'.trim(),
      email: email,
      image: current.image,
      token: current.token,
    );
  }
}
