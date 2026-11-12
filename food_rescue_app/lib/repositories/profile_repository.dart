import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import 'auth_repository.dart' show AuthException, AuthUser;

/// Kontrak sumber data profil. UI tidak tahu apakah datanya dari API atau fake.
abstract class ProfileRepository {
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String firstName,
    required String lastName,
    required String email,
  });
}

/// P9: request API profil — `PUT https://dummyjson.com/users/{id}`.
///
/// Mengembalikan [AuthUser] baru dengan data hasil server, token lama tetap
/// dipakai (endpoint ini tidak menerbitkan token baru).
class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository({
    http.Client? client,
    Duration timeout = const Duration(seconds: 12),
  }) : _api = ApiClient(client: client, timeout: timeout);

  final ApiClient _api;

  static String endpointFor(int userId) => 'https://dummyjson.com/users/$userId';

  @override
  Future<AuthUser> updateProfile({
    required AuthUser current,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final json = await _api.sendJson(
      method: 'PUT',
      endpoint: endpointFor(current.id),
      body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
      },
      onError: (message, statusCode) => AuthException(
        statusCode == null
            ? message
            : 'Gagal menyimpan profil ($message). Coba lagi.',
      ),
    );

    // Server mengembalikan objek user lengkap; hanya field yang kita ubah
    // yang diambil supaya token & id tetap dari sesi berjalan.
    return AuthUser(
      id: current.id,
      name: AuthUser.fullName({
        'firstName': json['firstName'] ?? firstName,
        'lastName': json['lastName'] ?? lastName,
      }),
      email: (json['email'] as String?)?.trim().isNotEmpty == true
          ? json['email'] as String
          : email,
      image: current.image,
      token: current.token,
    );
  }
}
