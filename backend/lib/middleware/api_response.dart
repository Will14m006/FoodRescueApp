import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Pembungkus respons JSON yang seragam untuk seluruh API.
///
/// Semua error yang bocor ke klien memakai bentuk yang SAMA, tanpa stack
/// trace dan tanpa detail internal — detail hanya dicatat di log server.
abstract class ApiResponse {
  static const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

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

  static Response error(int status, String message, {String? code}) {
    return json(
      {
        'error': {
          'code': code ?? _defaultCode(status),
          'message': message,
        },
      },
      status: status,
    );
  }

  static String _defaultCode(int status) => switch (status) {
        400 => 'bad_request',
        401 => 'unauthorized',
        403 => 'forbidden',
        404 => 'not_found',
        409 => 'conflict',
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

/// Middleware terakhir: mengubah exception apa pun menjadi 500 yang aman.
///
/// Tanpa ini, `shelf` mengirim halaman HTML berisi stack trace — persis
/// kebocoran yang kita larang.
Middleware errorHandler(void Function(Object error, StackTrace stack) onError) {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } catch (error, stack) {
        onError(error, stack);
        return ApiResponse.error(500, genericServerError);
      }
    };
  };
}
