import 'package:food_rescue_backend/middleware/access_log.dart';
import 'package:food_rescue_backend/middleware/api_response.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('satu baris log per request, memuat method/status/path', () async {
    final lines = <String>[];
    final handler = const Pipeline()
        .addMiddleware(accessLog(lines.add))
        .addHandler((Request request) => ApiResponse.ok({'ok': true}));

    await handler(Request('GET', Uri.parse('http://localhost/auth/me')));

    expect(lines, hasLength(1));
    expect(lines.single, contains('GET'));
    expect(lines.single, contains('200'));
    expect(lines.single, contains('/auth/me'));
  });

  test('query string TIDAK ikut dicatat (bisa memuat token)', () async {
    final lines = <String>[];
    final handler = const Pipeline()
        .addMiddleware(accessLog(lines.add))
        .addHandler((Request request) => ApiResponse.ok(null));

    await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/auth/me?token=rahasia123'),
      ),
    );

    expect(lines.single.contains('rahasia123'), isFalse);
  });

  test('exception dicatat sebagai status akhir, tanpa stack trace', () async {
    final lines = <String>[];
    final handler = const Pipeline()
        // Sama seperti produksi: accessLog di luar errorHandler.
        .addMiddleware(accessLog(lines.add))
        .addMiddleware(errorHandler((_, __) {}))
        .addHandler(
          (Request request) => throw const ApiException(401, 'salah'),
        );

    final response =
        await handler(Request('POST', Uri.parse('http://localhost/auth/login')));

    expect(response.statusCode, 401);
    expect(lines.single, contains('POST'));
    expect(lines.single, contains('401'));
    expect(lines.single.contains('ApiException'), isFalse);
    expect(lines.single.contains('#0'), isFalse);
  });
}
