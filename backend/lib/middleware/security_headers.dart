import 'package:shelf/shelf.dart';

/// Header keamanan yang dikirim di SETIAP respons, termasuk error.
///
/// Ini bukan pengganti HTTPS, tapi mencegah kelas masalah yang murah
/// dicegah: sniffing konten, framing, dan kebocoran referrer.
class SecurityHeaders {
  static const _headers = <String, String>{
    // Larang browser menebak tipe konten: JSON tidak boleh dieksekusi.
    'x-content-type-options': 'nosniff',
    // Origin lain tidak boleh menaruh / menyematkan aplikasi di iframe.
    'x-frame-options': 'DENY',
    // Jangan kirim URL lengkap (bisa memuat token) ke situs luar.
    'referrer-policy': 'no-referrer',
    // `1; mode=block` sudah usang dan di browser modern justru bisa
    // menimbulkan masalah; `0` adalah nilai yang direkomendasikan OWASP.
    'x-xss-protection': '0',
    // API ini tidak butuh kamera/mikrofon/lokasi.
    'permissions-policy': 'geolocation=(), microphone=(), camera=()',
  };

  /// Membungkus handler sehingga semua respons mendapat header di atas.
  ///
  /// `x-powered-by` tidak dihapus di sini, melainkan dengan mengirim
  /// `poweredByHeader: null` ke `shelf_io.serve` — cara resmi shelf. Kalau
  /// dihapus di middleware, `dart:io` menambahkannya kembali setelahnya.
  static Handler apply(Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      return response.change(headers: _headers);
    };
  }
}
