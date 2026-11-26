import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Kesalahan yang **disengaja** dan aman dikirim ke klien.
///
/// Apa pun yang bukan [ApiException] dianggap bug server: pesannya tidak
/// pernah keluar, hanya masuk log. Pesan di sini ditulis tangan, jadi tidak
/// mungkin memuat detail internal.
class ApiException implements Exception {
  const ApiException(this.status, this.message, {this.code});

  final int status;
  final String message;
  final String? code;

  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// Pembungkus respons JSON yang seragam untuk seluruh API.
///
/// Semua error yang bocor ke klien memakai bentuk yang SAMA, tanpa stack
/// trace dan tanpa detail internal — detail hanya dicatat di log server.
abstract class ApiResponse {
  static const _jsonHeaders = {
    'content-type': 'application/json; charset=utf-8',
  };

  static Response json(
    Object? body, {
    int status = 200,
    Map<String, String>? headers,
  }) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {..._jsonHeaders, ...?headers},
    );
  }

  static Response ok(Object? body) => json(body);

  static Response created(Object? body) => json(body, status: 201);

  static Response error(
    int status,
    String message, {
    String? code,
    Map<String, String>? headers,
  }) {
    return json(
      {
        'error': {
          'code': code ?? _defaultCode(status),
          'message': message,
        },
      },
      status: status,
      headers: headers,
    );
  }

  static String _defaultCode(int status) => switch (status) {
        400 => 'bad_request',
        401 => 'unauthorized',
        403 => 'forbidden',
        404 => 'not_found',
        409 => 'conflict',
        413 => 'payload_too_large',
        415 => 'unsupported_media_type',
        422 => 'unprocessable',
        429 => 'too_many_requests',
        >= 500 => 'internal_error',
        _ => 'error',
      };
}

/// Pesan untuk klien. Versi internal (stack trace, pesan SQL) tidak pernah
/// dikirim keluar.
const genericServerError =
    'Terjadi kesalahan pada server. Silakan coba lagi.';

/// Batas ukuran body. Token/pesan teks tidak pernah butuh lebih dari ini, dan
/// tanpa batas satu request bisa menghabiskan memori server.
const maxJsonBodyBytes = 8 * 1024;

/// Membaca body JSON objek. Semua penolakan menjadi [ApiException] dengan
/// status yang tepat, bukan exception liar yang berubah jadi 500.
Future<Map<String, dynamic>> readJsonObject(Request request) async {
  final contentType = request.headers['content-type']?.toLowerCase() ?? '';
  if (!contentType.startsWith('application/json')) {
    throw const ApiException(
      415,
      'Content-Type harus application/json.',
      code: 'unsupported_media_type',
    );
  }

  final declaredLength = request.contentLength;
  if (declaredLength != null && declaredLength > maxJsonBodyBytes) {
    throw const ApiException(
      413,
      'Body permintaan terlalu besar.',
      code: 'payload_too_large',
    );
  }

  final raw = await request.readAsString();
  if (raw.trim().isEmpty) {
    throw const ApiException(400, 'Body JSON tidak boleh kosong.');
  }
  // content-length bisa bohong (chunked), jadi ukuran nyata diperiksa juga.
  if (utf8.encode(raw).length > maxJsonBodyBytes) {
    throw const ApiException(
      413,
      'Body permintaan terlalu besar.',
      code: 'payload_too_large',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw const ApiException(400, 'Body bukan JSON yang valid.');
  }

  if (decoded is! Map<String, dynamic>) {
    throw const ApiException(400, 'Body JSON harus berupa objek.');
  }
  return decoded;
}

/// Membaca nilai string wajib dari body JSON.
String requireString(Map<String, dynamic> body, String key, {int? maxLength}) {
  final value = body[key];
  if (value is! String || value.trim().isEmpty) {
    throw ApiException(422, 'Field "$key" wajib diisi.', code: 'invalid_$key');
  }
  final trimmed = value.trim();
  if (maxLength != null && trimmed.length > maxLength) {
    throw ApiException(
      422,
      'Field "$key" maksimal $maxLength karakter.',
      code: 'invalid_$key',
    );
  }
  return trimmed;
}

/// Middleware terakhir: mengubah exception menjadi respons JSON yang aman.
///
/// [ApiException] diteruskan apa adanya (status + pesan yang sudah ditulis
/// tangan). Selain itu: 500 generik, detail hanya ke log server.
Middleware errorHandler(void Function(Object error, StackTrace stack) onError) {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return ApiResponse.error(e.status, e.message, code: e.code);
      } catch (error, stack) {
        onError(error, stack);
        return ApiResponse.error(500, genericServerError);
      }
    };
  };
}
