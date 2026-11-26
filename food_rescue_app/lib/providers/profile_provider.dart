import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';
import 'auth_provider.dart';

/// State update profil. Tiga tanggung jawab tetap terpisah:
///   - `ProfileFormScreen` : input + status UI
///   - `Validators`        : aturan input
///   - `ProfileRepository` : request API
class ProfileUpdateNotifier extends AsyncNotifier<AuthUser?> {
  @override
  AuthUser? build() => null;

  Future<void> save({
    required AuthUser current,
    required String name,
    required String email,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(
            current: current,
            name: name,
            email: email,
          ),
    );
  }

  void reset() => state = const AsyncData(null);
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ApiProfileRepository(api: ref.watch(apiClientProvider));
});

final profileUpdateProvider =
    AsyncNotifierProvider<ProfileUpdateNotifier, AuthUser?>(
  ProfileUpdateNotifier.new,
);
