import 'dart:convert';

import 'package:http/http.dart' as http;

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

    final first = json['firstName'] as String? ?? '';
    final last = json['lastName'] as String? ?? '';
    final name = '$first $last'.trim();

    return AuthUser(
      id: id,
      name: name.isEmpty ? (json['username'] as String? ?? 'Pengguna') : name,
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
/// - 400           -> [AuthException] "Username atau password salah"
/// - jaringan/JSON -> [AuthException]
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const endpoint = 'https://dummyjson.com/auth/login';

  @override
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'expiresInMins': 60,
            }),
          )
          .timeout(timeout);
    } on Exception {
      throw const AuthException(
        'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.',
      );
    }

    if (response.statusCode == 400 || response.statusCode == 401) {
      throw const AuthException('Username atau password salah.');
    }
    if (response.statusCode != 200) {
      throw AuthException(
        'Login gagal (error ${response.statusCode}). Coba lagi.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AuthException('Respons server tidak dapat dibaca.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AuthException('Format respons server tidak sesuai.');
    }

    return AuthUser.fromJson(decoded);
  }
}
