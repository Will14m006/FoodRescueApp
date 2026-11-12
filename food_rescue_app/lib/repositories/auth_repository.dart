import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';

/// Data user yang sedang login.
class AuthUser {
  final int id;
  final String name;
  final String email;
  final String? image;
  final String token;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.image,
  });

  /// Nama lengkap dari field `firstName` + `lastName`.
  ///
  /// P9: dipakai bersama oleh login dan update profil supaya aturan
  /// penyusunan nama tidak ditulis dua kali.
  static String fullName(Map<String, dynamic> json) {
    final first = json['firstName'] as String? ?? '';
    final last = json['lastName'] as String? ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? (json['username'] as String? ?? 'Pengguna') : name;
  }

  /// Validasi + mapping dari JSON `/auth/login`.
  ///
  /// Melempar [AuthException] kalau kontrak respons tidak sesuai.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final token = json['accessToken'];
    final email = json['email'];

    if (id is! int) throw const AuthException('Respons login tidak valid.');
    if (token is! String || token.isEmpty) {
      throw const AuthException('Token login tidak diterima.');
    }
    if (email is! String || email.isEmpty) {
      throw const AuthException('Email user tidak diterima.');
    }

    return AuthUser(
      id: id,
      name: fullName(json),
      email: email,
      image: json['image'] as String?,
      token: token,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<AuthUser> login({required String username, required String password});
}

/// P7 Advanced Feature #1: Autentikasi ke backend.
///
/// POST https://dummyjson.com/auth/login
/// - 200 + token   -> [AuthUser]
/// - 400/401       -> [AuthException] "Username atau password salah"
/// - jaringan/JSON -> [AuthException]
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({http.Client? client, Duration timeout = const Duration(seconds: 12)})
      : _api = ApiClient(client: client, timeout: timeout);

  final ApiClient _api;

  static const endpoint = 'https://dummyjson.com/auth/login';

  @override
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final json = await _api.sendJson(
      method: 'POST',
      endpoint: endpoint,
      body: {
        'username': username,
        'password': password,
        'expiresInMins': 60,
      },
      isSuccess: (status) => status == 200,
      onError: (message, statusCode) {
        if (statusCode == 400 || statusCode == 401) {
          return const AuthException('Username atau password salah.');
        }
        if (statusCode == null) return AuthException(message);
        return AuthException('Login gagal ($message). Coba lagi.');
      },
    );

    return AuthUser.fromJson(json);
  }
}
