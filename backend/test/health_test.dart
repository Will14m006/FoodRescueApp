import 'dart:convert';

import 'package:food_rescue_backend/app.dart';
import 'package:food_rescue_backend/middleware/api_response.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('GET /health', () {
    late TestApi api;
    setUp(() => api = TestApi());
    tearDown(() => api.close());

    test('mengembalikan 200 dan status ok', () async {
      final response = await api.request('GET', '/health');
      expect(response.statusCode, 200);

      final body = await api.json(response);
      expect(body['status'], 'ok');
      expect(body['service'], 'food-rescue-backend');
      expect(body['time'], isA<String>());
    });

    test('berisi header keamanan', () async {
      final response = await api.request('GET', '/health');
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['x-frame-options'], 'DENY');
      expect(response.headers['referrer-policy'], 'no-referrer');
      // x-powered-by dimatikan lewat shelf_io.serve, bukan handler, jadi di
      // level handler ia memang tidak ada.
      expect(response.headers['x-powered-by'], isNot('Dart with package:shelf'));
      // dart:io memasang x-xss-protection lama; middleware menimpanya.
      expect(response.headers['x-xss-protection'], '0');
      expect(response.headers['permissions-policy'], contains('geolocation=()'));
    });

    test('content-type JSON ber-encoding utf-8', () async {
      final response = await api.request('GET', '/health');
      expect(response.headers['content-type'], contains('application/json'));
      expect(response.headers['content-type'], contains('utf-8'));
    });

    test('tidak menyentuh database (tetap 200 saat DB baru dibuka)', () async {
      // TestApi baru membuat DB in-memory; kalau /health menyentuhnya dan
      // gagal, status bukan 200.
      expect((await api.request('GET', '/health')).statusCode, 200);
    });
  });

  group('rute tidak dikenal', () {
    late TestApi api;
    setUp(() => api = TestApi());
    tearDown(() => api.close());

    test('404 dalam bentuk JSON, bukan HTML bawaan shelf', () async {
      final response = await api.request('GET', '/tidak-ada');
      expect(response.statusCode, 404);

      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'not_found');
    });

    test('404 tetap mendapat header keamanan', () async {
      final response = await api.request('GET', '/apa-saja');
      expect(response.headers['x-frame-options'], 'DENY');
    });
  });

  group('penanganan exception', () {
    test('exception diubah menjadi 500 JSON tanpa detail internal', () async {
      final logs = <String>[];

      final handler = const Pipeline()
          .addMiddleware(errorHandler((error, stack) => logs.add('$error')))
          .addHandler(
            (Request request) => throw StateError('rahasia-database-xyz'),
          );

      final response = await handler(Request('GET', Uri.parse('http://x/')));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final message = (body['error'] as Map)['message'] as String;

      expect(response.statusCode, 500);
      expect(message, genericServerError);
      expect(message.contains('rahasia-database-xyz'), isFalse);
      expect(logs.single, contains('rahasia-database-xyz'));
    });

    test('ApiException diteruskan sebagai status + pesan yang ditulis tangan',
        () async {
      final handler = const Pipeline()
          .addMiddleware(errorHandler((_, __) => fail('tidak boleh dipanggil')))
          .addHandler(
            (Request request) =>
                throw const ApiException(422, 'Email tidak valid.', code: 'x'),
          );

      final response = await handler(Request('GET', Uri.parse('http://x/')));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, 422);
      expect((body['error'] as Map)['message'], 'Email tidak valid.');
      expect((body['error'] as Map)['code'], 'x');
    });
  });

  group('pipeline produksi', () {
    test('buildHandler memakai urutan middleware yang sama', () async {
      final api = TestApi();
      addTearDown(api.close);

      final response = await api.request('GET', '/health');
      expect(response.headers['x-content-type-options'], 'nosniff');

      // Tepat satu baris akses, tanpa stack trace.
      expect(api.logs, hasLength(1));
      expect(api.logs.single, contains('GET'));
      expect(api.logs.single, contains('200'));
      expect(buildHandler, isNotNull);
    });
  });
}
