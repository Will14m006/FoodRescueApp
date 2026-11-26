import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';

/// Hash password dengan bcrypt.
///
/// bcrypt memilih salt sendiri (16 byte, `Random.secure()`), jadi dua user
/// dengan password sama tetap menghasilkan hash berbeda.
class PasswordHasher {
  /// [cost] dibaca dari `BCRYPT_COST` (10..15). Default 12 ≈ 320 ms/hash di
  /// mesin dev — cukup lambat untuk penyerang, masih wajar untuk login.
  PasswordHasher({required this.cost})
      : _dummyHash = BCrypt.hashpw(
          _dummyPassword,
          BCrypt.gensalt(logRounds: cost),
        );

  /// Panjang minimum password. 8 adalah batas bawah yang lazim diterima.
  static const minLength = 8;

  /// bcrypt hanya memakai 72 byte pertama; lebih dari itu DITOLAK, bukan
  /// dipotong diam-diam, supaya user tidak mengira seluruh passwordnya berlaku.
  static const maxLengthBytes = 72;

  /// Dipakai saat email tidak ditemukan, agar biaya verifikasi sama dengan
  /// kasus email ada. Tanpa ini, waktu respons membocorkan email mana yang
  /// terdaftar (user enumeration).
  static const _dummyPassword = 'dummy-password-food-rescue-bukan-rahasia';

  final int cost;
  final String _dummyHash;

  String hash(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt(logRounds: cost));

  bool verify(String password, String storedHash) =>
      BCrypt.checkpw(password, storedHash);

  /// Hash pengganti saat user tidak ada. Hasil [verify] selalu `false`.
  String get dummyHash => _dummyHash;

  /// Validasi panjang dalam **byte** UTF-8, bukan karakter.
  static bool isLengthValid(String password) {
    final bytes = utf8.encode(password).length;
    return bytes >= minLength && bytes <= maxLengthBytes;
  }
}
