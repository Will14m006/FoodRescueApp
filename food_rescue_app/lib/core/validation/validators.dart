/// P9: aturan validasi input — satu tempat, terpisah dari widget.
///
/// Sebelumnya aturan "wajib diisi" ditulis ulang di `login_screen` dan
/// `booking_screen` dengan pesan yang sedikit berbeda. Sekarang UI hanya
/// memanggil validator; aturannya bisa diuji tanpa membangun widget.
abstract class Validators {
  /// Wajib diisi (tidak boleh kosong / hanya spasi).
  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi.';
    }
    return null;
  }

  /// Wajib diisi + panjang minimal [min] karakter.
  static String? minLength(
    String? value, {
    required String label,
    required int min,
  }) {
    final empty = required(value, label);
    if (empty != null) return empty;
    if (value!.length < min) {
      return '$label minimal $min karakter.';
    }
    return null;
  }

  /// Format email sederhana: `nama@domain.tld`.
  static String? email(String? value, {String label = 'Email'}) {
    final empty = required(value, label);
    if (empty != null) return empty;

    final pattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!pattern.hasMatch(value!.trim())) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  /// Bilangan bulat dalam rentang [min]..[max].
  static String? quantity(
    String? value, {
    required int min,
    required int max,
    String label = 'Jumlah',
  }) {
    final empty = required(value, label);
    if (empty != null) return empty;

    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return '$label harus berupa angka.';
    if (parsed < min) return 'Minimal $min.';
    if (parsed > max) return 'Melebihi batas maksimal ($max).';
    return null;
  }
}
