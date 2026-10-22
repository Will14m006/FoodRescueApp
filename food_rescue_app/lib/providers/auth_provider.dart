import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';

/// P7 Advanced Feature #1: Autentikasi.
///
/// State:
///   - `null`         -> belum login (UI menampilkan form)
///   - `AsyncLoading` -> sedang memanggil API login
///   - `AsyncData`    -> berhasil, berisi [AuthUser]
///   - `AsyncError`   -> gagal (password salah / jaringan), UI tampilkan pesan
class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  AuthUser? build() => null;

  Future<void> login({required String username, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).login(
            username: username,
            password: password,
          );
    });
  }

  void logout() {
    state = const AsyncData(null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository();
});

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);

/// User yang sedang login (null kalau belum login).
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});
