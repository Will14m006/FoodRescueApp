import 'package:shelf/shelf.dart';

import 'api_response.dart';

/// Batas atas `limit` supaya satu request tidak bisa menarik seluruh tabel.
const maxPageLimit = 200;

/// Paginasi sederhana `?limit=&offset=`.
///
/// Nilai tidak valid ditolak 422, bukan diam-diam diganti default: klien yang
/// salah harus tahu, bukan menampilkan halaman yang bukan permintaannya.
({int limit, int offset}) readPagination(Request request) {
  final params = request.url.queryParameters;

  int parse(String key, int fallback) {
    final raw = params[key];
    if (raw == null) return fallback;
    final value = int.tryParse(raw);
    if (value == null || value < 0) {
      throw ApiException(
        422,
        'Parameter "$key" harus bilangan bulat >= 0.',
        code: 'invalid_$key',
      );
    }
    return value;
  }

  final limit = parse('limit', 50);
  final offset = parse('offset', 0);
  if (limit < 1 || limit > maxPageLimit) {
    throw const ApiException(
      422,
      'Parameter "limit" harus antara 1 dan $maxPageLimit.',
      code: 'invalid_limit',
    );
  }
  return (limit: limit, offset: offset);
}
