import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/app_log.dart';
import 'api_exception.dart';

/// Satu-satunya jalan keluar HTTP aplikasi.
///
/// Sebelumnya tiap repository menyusun request sendiri (auth, katalog,
/// pesanan, profil) dengan penanganan error yang berbeda-beda. Sekarang semua
/// lewat sini: satu bentuk error, satu tempat menaruh token, satu batas waktu.
class ApiClient {
  ApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final Duration timeout;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  /// Kirim request dan kembalikan body JSON sebagai Map.
  ///
  /// [path] diawali `/` (mis. `/foods`). [token] dikirim sebagai
  /// `Authorization: Bearer` bila diisi. Respons 204 / body kosong dianggap
  /// objek kosong — bukan error.
  Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );

    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final payload = body == null ? null : jsonEncode(body);

    AppLog.info('$method ${uri.path}');

    final http.Response response;
    try {
      response = await _client
          .send(
            http.Request(method, uri)
              ..headers.addAll(headers)
              ..body = payload ?? '',
          )
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on Exception catch (e) {
      AppLog.error('$method ${uri.path} gagal (jaringan)', e);
      throw const ApiException(
        'Tidak bisa terhubung ke server. Pastikan backend berjalan.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      AppLog.info('$method ${uri.path} -> ${response.statusCode}');
      return _decodeObject(response.body, response.statusCode);
    }

    AppLog.warn('$method ${uri.path} -> HTTP ${response.statusCode}');
    throw ApiException(
      _serverMessage(response.body) ??
          'Permintaan gagal (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeObject(String raw, int statusCode) {
    if (raw.trim().isEmpty) return const {};

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      AppLog.error('body bukan JSON', e);
      throw ApiException(
        'Respons server tidak dapat dibaca.',
        statusCode: statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Format respons server tidak sesuai.',
        statusCode: statusCode,
      );
    }
    return decoded;
  }

  /// Backend menjawab error dengan `{"error":{"code":...,"message":...}}`.
  /// Kalau bentuknya lain (proxy, halaman HTML), pesan generik saja — body
  /// mentah tidak boleh muncul di UI.
  String? _serverMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
      }
    } on FormatException {
      // Bukan JSON: jatuh ke pesan generik.
    }
    return null;
  }
}
