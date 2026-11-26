import 'package:shelf/shelf.dart';

/// CORS untuk build web (Chrome/Edge). **Mati secara default.**
///
/// Kenapa tidak selalu `*`: API memakai header `Authorization`. Membuka
/// origin apa pun berarti situs mana pun bisa memanggil API ini dari browser
/// pengguna. Karena itu daftar origin harus eksplisit, diisi lewat
/// `CORS_ORIGINS` di `.env`.
///
/// `Access-Control-Allow-Credentials` sengaja **tidak** dikirim: autentikasi
/// lewat Bearer token, bukan cookie, jadi tidak butuh credentials.
class Cors {  Cors(this._allowedOrigins);

  /// Origin persis, mis. `http://localhost:5000`. Boleh `*` untuk dev saja.
  final List<String> _allowedOrigins;

  static const _methods = 'GET, POST, PATCH, DELETE, OPTIONS';
  static const _headers = 'authorization, content-type';

  bool get enabled => _allowedOrigins.isNotEmpty;

  Handler apply(Handler inner) {
    if (!enabled) return inner;

    return (Request request) async {
      final origin = request.headers['origin'];
      if (origin == null || !_matches(origin)) {
        return inner(request);
      }

      // Preflight: dijawab di sini supaya tidak menyentuh router/auth.
      if (request.method == 'OPTIONS') {
        return Response(204, headers: _headersFor(origin));
      }

      final response = await inner(request);
      return response.change(headers: _headersFor(origin));
    };
  }

  bool _matches(String origin) =>
      _allowedOrigins.contains('*') || _allowedOrigins.contains(origin);

  Map<String, String> _headersFor(String origin) => {
        // Selalu echo origin asli, termasuk saat `*`: respons jadi tidak
        // bisa di-cache untuk origin lain.
        'access-control-allow-origin': origin,
        'access-control-allow-methods': _methods,
        'access-control-allow-headers': _headers,
        'access-control-max-age': '600',
        'vary': 'origin',
      };
}
