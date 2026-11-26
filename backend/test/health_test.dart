import 'dart:convert';

import 'package:food_rescue_backend/app.dart';
import 'package:food_rescue_backend/middleware/api_response.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Handler yang dipakai test. Log ditampung, tidak dicetak, supaya keluaran
/// test tetap bersih.
Handler _handler({List<String>? sink}) =>
    buildHandler((message) => sink?.add(message));

Future<Response> _get(Handler handler, String path) async {
  return handler(Request('GET', Uri.parse('http://localhost$path')));
}

Future<Map<String, dynamic>> _json(Response response) async {
  return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
}

void main() {
  group('GET /health', () {
    test('mengembalikan 200 dan status ok', () async {
      final response = await _get(_handler(), '/health');
      expect(response.statusCode, 200);

      final body = await _json(response);
      expect(body['status'], 'ok');
      expect(body['service'], 'food-rescue-backend');
      expect(body['time'], isA<String>());
    });

    test('berisi header keamanan', () async {
      final response = await _get(_handler(), '/health');
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['x-frame-options'], 'DENY');
      expect(response.headers['referrer-policy'], 'no-referrer');
    });

    test('content-type JSON ber-encoding utf-8', () async {
      final response = await _get(_handler(), '/health');
      expect(response.headers['content-type'], contains('application/json'));
      expect(response.headers['content-type'], contains('utf-8'));
    });
  });

  group('rute tidak dikenal', () {
    test('404 dalam bentuk JSON, bukan HTML bawaan shelf', () async {
      final response = await _get(_handler(), '/tidak-ada');
      expect(response.statusCode, 404);
      expect(response.headers['content-type'], contains('application/json'));

      final body = await _json(response);
      expect((body['error'] as Map)['code'], 'not_found');
    });

    test('404 tetap mendapat header keamanan', () async {
      final response = await _get(_handler(), '/apa-saja');
      expect(response.headers['x-frame-options'], 'DENY');
    });
  });

  group('penanganan exception', () {
    test('exception diubah menjadi 500 JSON tanpa detail internal', () async {
      final logs = <String>[];

      // Pipeline yang sama dengan produksi, tapi handler-nya melempar.
      final handler = const Pipeline()
          .addMiddleware(
            errorHandler((error, stack) => logs.add('$error')),
          )
          .addMiddleware(
            (Handler inner) => (Request request) async {
              final response = await inner(request);
              return response;
            },
          )
          .addHandler(
            (Request request) => throw StateError('rahasia-database-xyz'),
          );

      final response = await handler(Request('GET', Uri.parse('http://x/')));
      expect(handler, isNotNull);

      expect(response.statusCode, 500);
      final body = await _json(response);
      final message = (body['error'] as Map)['message'] as String;

      // Klien hanya melihat pesan umum.
      expect(message, genericServerError);
      expect(message.contains('rahasia-database-xyz'), isFalse);
      expect(message.contains('StateError'), isFalse);

      // Detail tetap sampai ke log server.
      expect(logs.single, contains('rahasia-database-xyz'));
    });
  });
}
