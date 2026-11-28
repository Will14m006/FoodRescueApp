import 'dart:io';

import 'package:food_rescue_backend/app.dart';
import 'package:food_rescue_backend/media/photo_store.dart';
import 'package:food_rescue_backend/auth/jwt_service.dart';
import 'package:food_rescue_backend/auth/login_throttle.dart';
import 'package:food_rescue_backend/auth/password_hasher.dart';
import 'package:food_rescue_backend/db/database.dart';
import 'package:drift/native.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late Handler handler;
  late PhotoStore photos;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    photos = PhotoStore(
      directory: Directory.systemTemp.createTempSync('fr_cors_').path,
    );
    handler = buildHandler(
      log: (_) {},
      db: db,
      jwt: JwtService(secret: 'x' * 40, ttl: const Duration(minutes: 1)),
      hasher: PasswordHasher(cost: 10),
      throttle: LoginThrottle(),
      photos: photos,
      corsOrigins: const ['http://localhost:5000'],
    );
  });
  tearDown(() => db.close());

  Future<Response> send(String method, String path,
          {Map<String, String>? headers}) =>
      Future.sync(() => handler(Request(
            method,
            Uri.parse('http://localhost$path'),
            headers: headers,
          )));

  test('CORS mati secara default', () async {
    final noCors = buildHandler(
      log: (_) {},
      db: db,
      jwt: JwtService(secret: 'x' * 40, ttl: const Duration(minutes: 1)),
      hasher: PasswordHasher(cost: 10),
      throttle: LoginThrottle(),
      photos: photos,
    );
    final response = await Future.sync(() => noCors(Request(
          'GET',
          Uri.parse('http://localhost/health'),
          headers: {'origin': 'http://localhost:5000'},
        )));
    expect(response.headers['access-control-allow-origin'], isNull);
  });

  test('preflight 204 untuk origin yang diizinkan', () async {
    final response = await send('OPTIONS', '/auth/login',
        headers: {'origin': 'http://localhost:5000'});
    expect(response.statusCode, 204);
    expect(response.headers['access-control-allow-origin'],
        'http://localhost:5000');
    expect(response.headers['access-control-allow-headers'], contains('authorization'));
    expect(response.readAsString(), completion(isEmpty));
  });

  test('origin asing tidak mendapat header CORS', () async {
    final response = await send('GET', '/health',
        headers: {'origin': 'http://evil.example'});
    expect(response.statusCode, 200);
    expect(response.headers['access-control-allow-origin'], isNull);
  });

  test('respons error tetap mendapat header CORS', () async {
    final response = await send('GET', '/tidak-ada',
        headers: {'origin': 'http://localhost:5000'});
    expect(response.statusCode, 404);
    expect(response.headers['access-control-allow-origin'],
        'http://localhost:5000');
  });

  test('header keamanan tetap ada bersama CORS', () async {
    final response = await send('GET', '/health',
        headers: {'origin': 'http://localhost:5000'});
    expect(response.headers['x-frame-options'], 'DENY');
    expect(response.headers['vary'], 'origin');
  });
}
