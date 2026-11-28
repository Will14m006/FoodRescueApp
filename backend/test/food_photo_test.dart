import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'food_test.dart' show CatalogFixture;
import 'support.dart';

/// Foto menu: unggah biner, ganti, hapus, dan penyajian publik.
void main() {
  configureDriftForTests();
  late TestApi api;
  late CatalogFixture fixture;
  late String merchantToken;
  late String buyerToken;
  late int foodId;

  // PNG 1x1 asli — header `Content-Type` saja tidak cukup, isi file ikut
  // diperiksa lewat magic bytes.
  final pngBytes = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  setUp(() async {
    api = TestApi();
    fixture = CatalogFixture(api);
    (merchantToken, _) = await fixture.merchant();
    (buyerToken, _, _) = await registerAndLogin(api);
    foodId = await fixture.food(merchantToken);
  });
  tearDown(() => api.close());

  Future<Response> upload(
    List<int> bytes, {
    String contentType = 'image/png',
    String? token,
    int? targetId,
  }) =>
      Future.sync(() => api.handler(Request(
            'POST',
            Uri.parse('http://localhost/foods/${targetId ?? foodId}/photo'),
            body: bytes,
            headers: {
              'content-type': contentType,
              'authorization': 'Bearer ${token ?? merchantToken}',
            },
          )));

  group('POST /foods/<id>/photo', () {
    test('merchant mengunggah PNG → imageUrl terisi', () async {
      final response = await upload(pngBytes);
      expect(response.statusCode, 200);

      final body = await api.json(response);
      final url = (body['food'] as Map)['imageUrl'] as String;
      expect(url, startsWith('/uploads/'));
      expect(url, endsWith('.png'));
    });

    test('file benar-benar tertulis ke disk', () async {
      final body = await api.json(await upload(pngBytes));
      final url = (body['food'] as Map)['imageUrl'] as String;
      final name = url.split('/').last;

      final file = File('${api.uploads.path}${Platform.pathSeparator}$name');
      expect(file.existsSync(), isTrue);
      expect(await file.length(), pngBytes.length);
    });

    test('isi bukan gambar ditolak walau header benar', () async {
      final response = await upload(
        utf8.encode('ini bukan gambar sama sekali'),
      );
      expect(response.statusCode, 422);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'invalid_image');
    });

    test('tipe selain JPEG/PNG/WebP ditolak 415', () async {
      final response = await upload(pngBytes, contentType: 'image/gif');
      expect(response.statusCode, 415);
      final body = await api.json(response);
      expect((body['error'] as Map)['code'], 'unsupported_image_type');
    });

    test('SVG ditolak (bisa memuat skrip)', () async {
      final response = await upload(
        utf8.encode('<svg xmlns="http://www.w3.org/2000/svg">'
            '<script>alert(1)</script></svg>'),
        contentType: 'image/svg+xml',
      );
      expect(response.statusCode, 415);
    });

    test('buyer tidak bisa mengunggah → 403', () async {
      final response = await upload(pngBytes, token: buyerToken);
      expect(response.statusCode, 403);
    });

    test('merchant lain tidak bisa mengunggah ke makanan ini → 404', () async {
      final (otherToken, _) = await fixture.merchant(email: 'lain@example.com');
      final response = await upload(pngBytes, token: otherToken);
      expect(response.statusCode, 404);
    });

    test('tanpa token → 401', () async {
      final response = await Future.sync(() => api.handler(Request(
            'POST',
            Uri.parse('http://localhost/foods/$foodId/photo'),
            body: pngBytes,
            headers: {'content-type': 'image/png'},
          )));
      expect(response.statusCode, 401);
    });

    test('unggah ulang menghapus file lama', () async {
      final first = await api.json(await upload(pngBytes));
      final firstName =
          ((first['food'] as Map)['imageUrl'] as String).split('/').last;

      final second = await api.json(await upload(pngBytes));
      final secondName =
          ((second['food'] as Map)['imageUrl'] as String).split('/').last;

      expect(firstName, isNot(secondName));
      expect(
        File('${api.uploads.path}${Platform.pathSeparator}$firstName')
            .existsSync(),
        isFalse,
      );
    });
  });

  group('DELETE /foods/<id>/photo', () {
    test('menghapus foto mengembalikan imageUrl ke null', () async {
      await upload(pngBytes);

      final response = await api.request(
        'DELETE',
        '/foods/$foodId/photo',
        token: merchantToken,
      );
      expect(response.statusCode, 200);

      final body = await api.json(response);
      expect((body['food'] as Map)['imageUrl'], isNull);
    });
  });

  group('GET /uploads/<file>', () {
    test('foto bisa diambil tanpa token', () async {
      final body = await api.json(await upload(pngBytes));
      final name = ((body['food'] as Map)['imageUrl'] as String).split('/').last;

      final response = await api.request('GET', '/uploads/$name');
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      // File acak & tidak pernah berubah → cache panjang aman.
      expect(response.headers['cache-control'], contains('immutable'));
      expect(
        (await response.read().expand((c) => c).length),
        pngBytes.length,
      );
    });

    test('nama file tak dikenal → 404', () async {
      final response = await api.request('GET', '/uploads/tidakada.png');
      expect(response.statusCode, 404);
    });

    test('path traversal ditolak, bukan membaca file di luar folder', () async {
      for (final path in [
        '/uploads/..%2F..%2F.env',
        '/uploads/..%2Ffood_rescue.db',
        '/uploads/%2Fetc%2Fpasswd',
      ]) {
        final response = await api.request('GET', path);
        expect(response.statusCode, 404, reason: path);
      }
    });
  });

  group('katalog', () {
    test('imageUrl ikut di GET /foods', () async {
      await upload(pngBytes);

      final body = await api.json(await api.request('GET', '/foods'));
      final foods = body['foods'] as List;
      final food = foods.firstWhere((f) => (f as Map)['id'] == foodId);
      expect((food as Map)['imageUrl'], startsWith('/uploads/'));
    });

    test('makanan tanpa foto: imageUrl null, bukan string kosong', () async {
      final body = await api.json(await api.request('GET', '/foods'));
      final foods = body['foods'] as List;
      final food = foods.firstWhere((f) => (f as Map)['id'] == foodId);
      expect((food as Map)['imageUrl'], isNull);
    });
  });
}
