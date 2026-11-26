import 'package:shelf/shelf.dart';

import '../db/database.dart';
import '../middleware/api_response.dart';
import 'jwt_service.dart';

/// Kunci `request.context` tempat [AuthUser] disimpan.
const authUserContextKey = 'food-rescue.auth-user';

/// User yang sedang memanggil. Hanya valid di handler yang dibungkus
/// [authGuard]; kalau tidak, ini bug programmer dan melempar.
AuthUser authenticatedUser(Request request) {
  final user = request.context[authUserContextKey];
  if (user is! AuthUser) {
    throw StateError('Handler butuh auth, tapi authGuard belum dipasang.');
  }
  return user;
}

/// Gerbang tunggal untuk rute ber-token.
///
/// `Authorization: Bearer <jwt>` wajib ada; token diverifikasi [JwtService].
/// Semua kegagalan token dijawab **401 yang identik**, jadi penyerang tidak
/// bisa membedakan "tidak ada token", "tanda tangan salah", dan "kedaluwarsa".
///
/// [roles] kosong berarti cukup login. Bila diisi dan role tidak cocok →
/// **403**. Di titik itu identitas pemanggil sudah diketahui, jadi
/// membedakan 401/403 tidak membocorkan apa pun.
Middleware authGuard(JwtService jwt, {Set<UserRole> roles = const {}}) {
  return (Handler inner) {
    return (Request request) {
      final header = request.headers['authorization'];
      if (header == null || !header.toLowerCase().startsWith('bearer ')) {
        return _unauthorized();
      }

      final token = header.substring(7).trim();
      if (token.isEmpty) return _unauthorized();

      final user = jwt.verify(token);
      if (user == null) return _unauthorized();

      if (roles.isNotEmpty && !roles.contains(user.role)) {
        return ApiResponse.error(
          403,
          'Peran Anda tidak berhak mengakses endpoint ini.',
        );
      }

      return inner(request.change(context: {authUserContextKey: user}));
    };
  };
}

Response _unauthorized() => ApiResponse.error(
      401,
      'Token tidak valid atau sudah kedaluwarsa. Silakan login ulang.',
      headers: {'www-authenticate': 'Bearer'},
    );
