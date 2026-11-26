import 'dart:convert';

import 'package:food_rescue_backend/auth/jwt_service.dart';
import 'package:food_rescue_backend/db/database.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  configureDriftForTests();
  late JwtService jwt;

  setUp(() {
    jwt = JwtService(secret: testSecret, ttl: const Duration(minutes: 60));
  });

  group('JwtService.issue + verify', () {
    test('token yang diterbitkan dapat diverifikasi kembali', () {
      final token = jwt.issue(userId: 42, role: UserRole.merchant);

      final user = jwt.verify(token);
      expect(user, isNotNull);
      expect(user!.id, 42);
      expect(user.role, UserRole.merchant);
    });

    test('id dan role berbeda menghasilkan token berbeda', () {
      final a = jwt.issue(userId: 1, role: UserRole.buyer);
      final b = jwt.issue(userId: 2, role: UserRole.buyer);
      expect(a, isNot(b));
    });

    test('token berisi exp, sehingga tidak berlaku selamanya', () {
      final token = jwt.issue(userId: 1, role: UserRole.buyer);
      final payload = token.split('.')[1];
      // decode manual: tidak butuh signature di sini
      final parts = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = String.fromCharCodes(base64Url.decode(parts));
      expect(decoded, contains('"exp"'));
    });
  });

  group('JwtService.verify — token yang harus DITOLAK', () {
    test('token yang ditandatangani secret lain', () {
      final asing = JwtService(
        secret: 'secret-lain-yang-tidak-dipakai-server-0123456789',
        ttl: const Duration(minutes: 60),
      );
      expect(jwt.verify(asing.issue(userId: 1, role: UserRole.admin)), isNull);
    });

    test('token kedaluwarsa', () async {
      final pendek = JwtService(
        secret: testSecret,
        ttl: const Duration(milliseconds: 1),
      );
      final token = pendek.issue(userId: 1, role: UserRole.buyer);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(pendek.verify(token), isNull);
    });

    test('string sampah', () {
      expect(jwt.verify('bukan-token'), isNull);
      expect(jwt.verify(''), isNull);
      expect(jwt.verify('a.b.c'), isNull);
    });

    test('token tanpa role', () {
      final token = jwt.issue(userId: 1, role: UserRole.buyer);
      // Ganti payload dengan yang tidak punya role.
      final bagian = token.split('.');
      final payload = base64Url.encode(
        // ignore: avoid_dynamic_calls
        utf8.encode('{"sub":"1","exp":9999999999,"iss":"food-rescue-api"}'),
      ).replaceAll('=', '');
      expect(jwt.verify('${bagian[0]}.$payload.${bagian[2]}'), isNull);
    });

    test('role yang tidak dikenal', () {
      final palsu = JwtService(
        secret: testSecret,
        ttl: const Duration(minutes: 60),
      );
      final token = jwt.issue(userId: 1, role: UserRole.buyer);
      final bagian = token.split('.');
      final payload = base64Url.encode(
        utf8.encode(
          '{"sub":"1","role":"superadmin","exp":9999999999,'
          '"iss":"food-rescue-api"}',
        ),
      ).replaceAll('=', '');
      expect(palsu.verify('${bagian[0]}.$payload.${bagian[2]}'), isNull);
    });

    test('sub bukan angka', () {
      final token = jwt.issue(userId: 1, role: UserRole.buyer);
      final bagian = token.split('.');
      final payload = base64Url.encode(
        utf8.encode(
          '{"sub":"bukan-angka","role":"buyer","exp":9999999999,'
          '"iss":"food-rescue-api"}',
        ),
      ).replaceAll('=', '');
      expect(jwt.verify('${bagian[0]}.$payload.${bagian[2]}'), isNull);
    });
  });
}
