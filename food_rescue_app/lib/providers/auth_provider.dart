import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/session/session_store.dart';
import '../models/user_role.dart';
import '../repositories/auth_repository.dart';

/// Satu `ApiClient` untuk seluruh aplikasi: satu base URL, satu timeout,
/// satu perilaku error, dan satu `http.Client` yang dipakai ulang.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(api: ref.watch(apiClientProvider));
});

/// State autentikasi.
///
///   - `AsyncData(null)`  -> belum login
///   - `AsyncLoading`     -> memanggil API
///   - `AsyncData(user)`  -> login
///   - `AsyncError`       -> gagal (password salah / jaringan)
class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    // Pulihkan sesi saat aplikasi dibuka. Token diverifikasi ke server, jadi
    // token yang sudah dicabut/diubah perannya tidak dipakai lagi.
    final stored = await ref.read(sessionStoreProvider).read();
    if (stored == null) return null;

    try {
      final user = await ref.read(authRepositoryProvider).me(stored.token);
      if (user == null) {
        await ref.read(sessionStoreProvider).clear();
        return null;
      }
      await ref.read(sessionStoreProvider).write(StoredSession.fromUser(user));
      return user;
    } on Exception {
      // Backend belum jalan saat aplikasi dibuka: tetap pakai sesi lokal
      // supaya UI tidak terasa "logout sendiri". Request berikutnya akan
      // memunculkan error jaringan yang jelas.
      return AuthUser(
        id: stored.id,
        name: stored.name,
        email: stored.email,
        role: stored.role,
        token: stored.token,
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      await ref.read(sessionStoreProvider).write(StoredSession.fromUser(user));
      return user;
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).register(
            name: name,
            email: email,
            password: password,
            role: role,
          );
      await ref.read(sessionStoreProvider).write(StoredSession.fromUser(user));
      return user;
    });
  }

  Future<void> logout() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }

  /// Dipakai setelah update profil supaya UI langsung menampilkan data baru.
  Future<void> replaceUser(AuthUser user) async {
    await ref.read(sessionStoreProvider).write(StoredSession.fromUser(user));
    state = AsyncData(user);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);

/// User yang sedang login (null kalau belum login / masih memuat sesi).
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});

/// Peran aktif. Default buyer hanya saat belum login.
final currentRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(currentUserProvider)?.role ?? UserRole.buyer;
});

/// Base URL yang sedang dipakai — ditampilkan di layar login supaya jelas
/// aplikasi menembak server mana saat demo.
final apiBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(apiClientProvider).baseUrl;
});

/// Dipakai test supaya `ApiConfig` tidak mengubah default.
String debugDefaultBaseUrl() => ApiConfig.baseUrl;
