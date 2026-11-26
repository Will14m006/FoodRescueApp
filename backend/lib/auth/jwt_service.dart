import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../db/database.dart';

/// User yang sudah terautentikasi, hasil verifikasi token.
///
/// Sengaja hanya memuat id + role: middleware tidak boleh bergantung pada
/// data lain yang bisa basi (role bisa berubah, token tetap lama).
class AuthUser {
  const AuthUser({required this.id, required this.role});

  final int id;
  final UserRole role;

  @override
  String toString() => 'AuthUser(id=$id, role=${role.name})';
}

/// Penerbit & pemverifikasi token JWT.
///
/// Satu-satunya tempat yang menyentuh [secret]. Kunci dibuat sekali di
/// constructor supaya tidak ada objek baru per request.
class JwtService {
  JwtService({required String secret, required this.ttl})
      : _key = SecretKey(secret);

  /// Masa berlaku token. Tidak ada refresh token (lihat catatan sesi).
  final Duration ttl;

  final SecretKey _key;

  /// Penanda token ini milik API kita, bukan token lain yang kebetulan
  /// ditandatangani dengan secret yang sama.
  static const issuer = 'food-rescue-api';

  /// Algoritma dikunci. Tanpa ini, token yang ditandatangani HS512 dengan
  /// secret yang sama juga akan diterima — permukaan serangan tanpa manfaat.
  static const _algorithm = JWTAlgorithm.HS256;

  String issue({required int userId, required UserRole role}) {
    final jwt = JWT(
      {'role': role.name},
      subject: '$userId',
      issuer: issuer,
    );
    return jwt.sign(_key, algorithm: _algorithm, expiresIn: ttl);
  }

  /// Mengembalikan [AuthUser], atau `null` bila token tidak sah dengan alasan
  /// apa pun (kedaluwarsa, tanda tangan salah, claim kurang).
  ///
  /// Klien tidak boleh tahu alasan kegagalannya — itu informasi gratis untuk
  /// penyerang.
  AuthUser? verify(String token) {
    final JWT jwt;
    try {
      jwt = JWT.verify(
        token,
        _key,
        issuer: issuer,
        audience: null,
      );
    } on JWTException {
      return null;
    }

    if (jwt.header?['alg'] != _algorithm.name) return null;

    final payload = jwt.payload;
    if (payload is! Map) return null;

    // Wajib ada: tanpa `exp`, token berlaku selamanya.
    if (payload['exp'] is! num) return null;

    final userId = int.tryParse(jwt.subject ?? '');
    if (userId == null) return null;

    final roleName = payload['role'];
    if (roleName is! String) return null;

    for (final candidate in UserRole.values) {
      if (candidate.name == roleName) {
        return AuthUser(id: userId, role: candidate);
      }
    }
    // Role yang tidak dikenal = token dibuat oleh versi lain / dipalsukan.
    return null;
  }
}
