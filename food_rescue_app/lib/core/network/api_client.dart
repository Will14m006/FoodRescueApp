import 'dart:convert';

import 'package:http/http.dart' as http;

/// P9: helper HTTP bersama untuk repository yang memanggil API JSON.
///
/// Sebelumnya blok `try { post().timeout() } on Exception`, pengecekan status,
/// dan `jsonDecode` disalin di `auth_repository`, `order_repository`, dan
/// `profile_repository`. Sekarang satu tempat, satu perilaku.
class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Kirim JSON dan kembalikan body yang sudah di-decode sebagai Map.
  ///
  /// [onError] dipakai supaya tiap fitur tetap punya pesan errornya sendiri
  /// (auth: "Username atau password salah", order: "Gagal menyimpan pesanan").
  /// [statusCode] hanya terisi kalau server merespons; null = gagal jaringan.
  Future<Map<String, dynamic>> sendJson({
    required String method,
    required String endpoint,
    required Map<String, dynamic> body,
    required Exception Function(String message, int? statusCode) onError,
    bool Function(int status)? isSuccess,
  }) async {
    final ok = isSuccess ?? (status) => status == 200 || status == 201;

    final http.Response response;
    try {
      final uri = Uri.parse(endpoint);
      const headers = {'Content-Type': 'application/json'};
      final payload = jsonEncode(body);
      final duration = timeout;

      response = await switch (method) {
        'PUT' => _client.put(uri, headers: headers, body: payload).timeout(duration),
        'PATCH' =>
          _client.patch(uri, headers: headers, body: payload).timeout(duration),
        _ => _client.post(uri, headers: headers, body: payload).timeout(duration),
      };
    } on Exception {
      throw onError(
        'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.',
        null,
      );
    }

    if (!ok(response.statusCode)) {
      throw onError('error ${response.statusCode}', response.statusCode);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw onError('Respons server tidak dapat dibaca.', response.statusCode);
    }

    if (decoded is! Map<String, dynamic>) {
      throw onError('Format respons server tidak sesuai.', response.statusCode);
    }

    return decoded;
  }
}
