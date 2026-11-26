// Helper test bersama: sesi palsu supaya widget test tidak menyentuh
// jaringan maupun storage perangkat.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/core/session/session_store.dart';
import 'package:food_rescue_app/models/user_role.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/location_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';

const testUser = AuthUser(
  id: 1,
  name: 'William',
  email: 'william@test.com',
  role: UserRole.buyer,
  token: 'token-test',
);

/// Repositori auth palsu: `me()` selalu mengembalikan [user].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user = testUser});

  final AuthUser user;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async =>
      user;

  @override
  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.buyer,
  }) async =>
      user;

  @override
  Future<AuthUser?> me(String token) async => user;
}

/// Lokasi palsu supaya widget test tidak meminta izin GPS.
class FakeLocationRepository implements LocationRepository {
  @override
  Future<LocationResult> getCurrentPosition() async =>
      const LocationResult(permission: LocationPermissionState.granted);

  @override
  Future<bool> openAppSettings() async => true;
}

/// Ganti platform SharedPreferences ke memori supaya `SessionStore` dan
/// `ProofPhotoStore` tidak menyentuh disk. Kembalikan store yang sudah berisi
/// sesi [user] (null = belum login).
Future<SessionStore> useInMemorySession({AuthUser? user = testUser}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final store = SessionStore(prefs: SharedPreferencesAsync());

  if (user != null) {
    await store.write(
      StoredSession(
        token: user.token,
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      ),
    );
  }
  return store;
}

/// Override standar: sesi palsu + auth + lokasi.
Future<List<Override>> sessionOverrides({AuthUser? user = testUser}) async {
  final store = await useInMemorySession(user: user);
  return [
    sessionStoreProvider.overrideWithValue(store),
    authRepositoryProvider
        .overrideWithValue(FakeAuthRepository(user: user ?? testUser)),
    locationRepositoryProvider.overrideWithValue(FakeLocationRepository()),
  ];
}

/// Isi mentah storage sesi — dipakai test yang memeriksa isi penyimpanan.
String encodeSession({
  required String token,
  int id = 1,
  String name = 'William',
  String email = 'william@test.com',
  String role = 'buyer',
}) =>
    jsonEncode({
      'token': token,
      'id': id,
      'name': name,
      'email': email,
      'role': role,
    });
