import 'dart:math';

/// Kode pick-up yang dibagikan ke pembeli dan divalidasi merchant.
///
/// Format `RESCUE-XXXXXXXX`:
///   - alfabet tanpa `0/O/1/I/L` supaya tidak salah baca saat ditunjukkan
///     di layar HP atau disebut lewat telepon;
///   - 8 karakter dari 32 simbol = 32⁸ ≈ 1,1 × 10¹² kemungkinan, jadi
///     menebak kode secara acak tidak praktis;
///   - [Random.secure] karena kode ini setara kunci — bukan hiasan.
class PickupCode {
  /// Nilai ini juga dipakai retry saat tabrakan unik.
  static const maxAttempts = 5;

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final _random = Random.secure();

  static String generate() {
    final buffer = StringBuffer('RESCUE-');
    for (var i = 0; i < 8; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }
}
