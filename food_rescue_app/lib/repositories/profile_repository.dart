import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import 'auth_repository.dart' show AuthUser;

abstract class ProfileRepository {
  /// Kirim nama & email baru. Server mengembalikan user terbaru.
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String name,
    required String email,
  });
}

/// `PATCH /auth/me` — hanya nama & email. Role dan password tidak bisa
/// diubah lewat endpoint ini; backend menolak field tersebut dengan diam
/// (diabaikan), jadi UI juga tidak menawarkannya.
class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository({required this.api});

  final ApiClient api;

  @override
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String name,
    required String email,
  }) async {
    final body = await api.request(
      method: 'PATCH',
      path: '/auth/me',
      token: current.token,
      body: {'name': name.trim(), 'email': email.trim()},
    );

    final user = body['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Respons server tidak sesuai.');
    }
    // Token tidak diterbitkan ulang oleh endpoint ini; pakai token lama.
    return AuthUser.fromJson(user, token: current.token);
  }
}
