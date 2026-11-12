import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

/// P9: state update profil. Memisahkan 3 tanggung jawab:
///   - `ProfileForm` (screen/widget): input + status UI
///   - `Validators`: aturan input
///   - `ProfileRepository`: request API
class ProfileUpdateNotifier extends AsyncNotifier<AuthUser?> {
  @override
  AuthUser? build() => null;

  Future<void> save({
    required AuthUser current,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(
            current: current,
            firstName: firstName,
            lastName: lastName,
            email: email,
          ),
    );
  }

  void reset() => state = const AsyncData(null);
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ApiProfileRepository();
});

final profileUpdateProvider =
    AsyncNotifierProvider<ProfileUpdateNotifier, AuthUser?>(
  ProfileUpdateNotifier.new,
);
