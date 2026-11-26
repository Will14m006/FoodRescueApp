import 'dart:convert';

import 'package:drift/native.dart';
import 'package:food_rescue_backend/app.dart';
import 'package:food_rescue_backend/auth/jwt_service.dart';
import 'package:food_rescue_backend/auth/login_throttle.dart';
import 'package:food_rescue_backend/auth/password_hasher.dart';
import 'package:food_rescue_backend/db/database.dart';
import 'package:shelf/shelf.dart';

/// Secret sintetis khusus test — tidak pernah dipakai server sungguhan.
const testSecret = 'test-only-secret-0123456789abcdef0123456789abcdef';

/// Biaya bcrypt terendah yang masih aman, supaya test tidak lambat.
const testBcryptCost = 10;

/// Satu instance API lengkap di atas database in-memory.
class TestApi {
  TestApi({
    Duration ttl = const Duration(minutes: 60),
    int maxAttempts = 5,
  })  : db = AppDatabase(NativeDatabase.memory()),
        jwt = JwtService(secret: testSecret, ttl: ttl),
        hasher = PasswordHasher(cost: testBcryptCost),
        throttle = LoginThrottle(maxAttempts: maxAttempts);

  final AppDatabase db;
  final JwtService jwt;
  final PasswordHasher hasher;
  final LoginThrottle throttle;

  /// Semua pesan yang dicatat server (termasuk detail error internal).
  final logs = <String>[];

  late final Handler handler = buildHandler(
    log: logs.add,
    db: db,
    jwt: jwt,
    hasher: hasher,
    throttle: throttle,
  );

  Future<Response> request(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String>? headers,
  }) {
    final merged = <String, String>{
      if (body != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      ...?headers,
    };

    return Future.sync(
      () => handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: body == null ? null : jsonEncode(body),
          headers: merged,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async {
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  Future<void> close() => db.close();
}

/// Daftar user lalu kembalikan token-nya.
Future<(String token, Map<String, dynamic> user, Map<String, dynamic> body)>
    registerAndLogin(
  TestApi api, {
  String email = 'buyer@example.com',
  String password = 'PasswordKuat123',
  String name = 'Buyer',
  String? role,
}) async {
  final response = await api.request('POST', '/auth/register', body: {
    'email': email,
    'password': password,
    'name': name,
    if (role != null) 'role': role,
  });

  final body = await api.json(response);
  return (
    body['token'] as String,
    body['user'] as Map<String, dynamic>,
    body,
  );
}
