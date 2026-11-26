import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/user_role.dart';

/// User yang sedang login, termasuk token Bearer-nya.
class AuthUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final String token;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  AuthUser copyWith({String? name, String? email, String? token}) {
    return AuthUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role,
      token: token ?? this.token,
    );
  }

  /// Dari `{"user": {...}}` milik `/auth/login` dan `/auth/register`.
  factory AuthUser.fromJson(
    Map<String, dynamic> json, {
    required String token,
  }) {
    final id = json['id'];
    final email = json['email'];
    final name = json['name'];

    if (id is! int) throw const ApiException('Respons login tidak valid.');
    if (email is! String || email.isEmpty) {
      throw const ApiException('Email user tidak diterima.');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const ApiException('Nama user tidak diterima.');
    }

    return AuthUser(
      id: id,
      name: name.trim(),
      email: email,
      role: UserRole.fromName(json['role'] as String?),
      token: token,
    );
  }
}

abstract class AuthRepository {
  Future<AuthUser> login({required String email, required String password});

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role,
  });

  /// Pulihkan sesi dari token tersimpan. `null` = token sudah tidak berlaku.
  Future<AuthUser?> me(String token);
}

/// Autentikasi lewat backend sendiri (`/auth/*`).
///
/// Password dikirim sekali saat login/daftar dan tidak pernah disimpan di
/// perangkat — yang disimpan hanya token.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required this.api});

  final ApiClient api;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final body = await api.request(
      method: 'POST',
      path: '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _withToken(body);
  }

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.buyer,
  }) async {
    final body = await api.request(
      method: 'POST',
      path: '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
      },
    );
    return _withToken(body);
  }

  @override
  Future<AuthUser?> me(String token) async {
    try {
      final body = await api.request(
        method: 'GET',
        path: '/auth/me',
        token: token,
      );
      final user = body['user'];
      if (user is! Map<String, dynamic>) return null;
      return AuthUser.fromJson(user, token: token);
    } on ApiException catch (e) {
      // 401 = token kedaluwarsa/dicabut; pemanggil membuang sesi lokal.
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  AuthUser _withToken(Map<String, dynamic> body) {
    final token = body['token'];
    final user = body['user'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Token login tidak diterima.');
    }
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Data user tidak diterima.');
    }
    return AuthUser.fromJson(user, token: token);
  }
}
