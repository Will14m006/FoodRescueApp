import 'package:shelf/shelf.dart';

/// Header keamanan yang dikirim di SETIAP respons, termasuk error.
///
/// Ini bukan pengganti HTTPS, tapi mencegah kelas masalah yang murah
/// dicegah: sniffing konten, framing, dan kebocoran referrer.
class SecurityHeaders {
  static const _headers = <String, String>{
    // Larang browser menebak tipe konten: JSON tidak boleh dieksekusi.
    'x-content-type-options': 'nosniff',
    // Origin lain tidak boleh menaruh /menyematkan aplikasi di iframe.
    'x-frame-options': 'DENY',
    // Jangan kirim URL lengkap (bisa memuat token) ke situs luar.
    'referrer-policy': 'no-referrer',
  };

  /// Membungkus handler sehingga semua respons mendapat header di atas,
  /// plus menghapus `x-powered-by` yang dipasang shelf secara otomatis.
  ///
  /// `x-powered-by` membocorkan stack (Dart + shelf) — informasi gratis untuk
  /// penyerang. Tidak ada klien yang membutuhkannya.
  static Handler apply(Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      return response.change(
        headers: {..._headers, 'x-powered-by': ''},
      );
    };
  }
}
