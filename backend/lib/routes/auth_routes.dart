import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../auth/login_throttle.dart';
import '../auth/password_hasher.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import 'mappers.dart';

/// Semua endpoint `/auth/*`.
///
/// Peran `admin` **tidak pernah** bisa didaftarkan lewat HTTP. Kalau bisa,
/// siapa pun yang menemukan endpoint register menjadi admin. Akun admin
/// dibuat lewat seed CLI.
Router authRoutes({
  required AppDatabase db,
  required JwtService jwt,
  required PasswordHasher hasher,
  required LoginThrottle throttle,
}) {
  final router = Router();

  router.post('/auth/register', (Request request) async {
    final body = await readJsonObject(request);

    final email = normalizeEmail(requireString(body, 'email', maxLength: 254));
    if (!isValidEmail(email)) {
      throw const ApiException(
        422,
        'Format email tidak valid.',
        code: 'invalid_email',
      );
    }

    final password = requireString(body, 'password');
    if (!PasswordHasher.isLengthValid(password)) {
      throw ApiException(
        422,
        'Password harus ${PasswordHasher.minLength}–${PasswordHasher.maxLengthBytes} byte.',
        code: 'invalid_password',
      );
    }

    final name = requireString(body, 'name', maxLength: 120);

    // Default buyer. Merchant boleh mendaftar sendiri (nanti membuat toko),
    // admin hanya lewat seed.
    final role = _selfServiceRole(body['role']);

    final existing = await (db.select(db.users)
          ..where((t) => t.email.equals(email)))
        .getSingleOrNull();
    if (existing != null) {
      throw const ApiException(
        409,
        'Email sudah terdaftar.',
        code: 'email_taken',
      );
    }

    final User user;
    try {
      user = await db.into(db.users).insertReturning(
            UsersCompanion.insert(
              email: email,
              passwordHash: hasher.hash(password),
              name: name,
              role: role,
            ),
          );
    } catch (_) {
      // Dua request paralel bisa lolos pengecekan di atas; UNIQUE index di
      // kolom email yang menjadi penentu akhir.
      final raced = await (db.select(db.users)
            ..where((t) => t.email.equals(email)))
          .getSingleOrNull();
      if (raced != null) {
        throw const ApiException(
          409,
          'Email sudah terdaftar.',
          code: 'email_taken',
        );
      }
      rethrow;
    }

    return ApiResponse.created({
      'token': jwt.issue(userId: user.id, role: user.role),
      'tokenType': 'Bearer',
      'expiresIn': jwt.ttl.inSeconds,
      'user': publicUser(user),
    });
  });

  router.post('/auth/login', (Request request) async {
    final body = await readJsonObject(request);

    final email = normalizeEmail(requireString(body, 'email', maxLength: 254));
    final password = requireString(body, 'password');

    final throttleKey = LoginThrottle.keyFor(request, email);
    if (throttle.isBlocked(throttleKey)) {
      throw const ApiException(
        429,
        'Terlalu banyak percobaan login. Coba lagi beberapa menit lagi.',
        code: 'too_many_attempts',
      );
    }

    final user = await (db.select(db.users)
          ..where((t) => t.email.equals(email)))
        .getSingleOrNull();

    // Selalu jalankan bcrypt, termasuk saat email tidak ada. Kalau tidak,
    // respons "email tidak ditemukan" jauh lebih cepat dan email terdaftar
    // bisa dienumerasi lewat waktu respons.
    final matches = hasher.verify(password, user?.passwordHash ?? hasher.dummyHash);

    if (user == null || !matches) {
      throttle.recordFailure(throttleKey);
      // Pesan dan status identik untuk kedua kasus.
      throw const ApiException(
        401,
        'Email atau password salah.',
        code: 'invalid_credentials',
      );
    }

    // Password benar tapi akun ditangguhkan. Dicek SETELAH verifikasi password
    // supaya penyerang tidak bisa memakai pesan ini untuk menebak akun mana
    // yang ditangguhkan tanpa tahu passwordnya.
    if (!user.isActive) {
      throw const ApiException(
        403,
        'Akun ini ditangguhkan. Hubungi admin Food Rescue.',
        code: 'account_suspended',
      );
    }

    throttle.reset(throttleKey);
    return ApiResponse.ok({
      'token': jwt.issue(userId: user.id, role: user.role),
      'tokenType': 'Bearer',
      'expiresIn': jwt.ttl.inSeconds,
      'user': publicUser(user),
    });
  });

  // Cukup login — dipakai aplikasi untuk memulihkan sesi saat dibuka ulang.
  final meHandler = authGuard(jwt)((Request request) async {
    final auth = authenticatedUser(request);
    final user =
        await (db.select(db.users)..where((t) => t.id.equals(auth.id)))
            .getSingleOrNull();

    // Token sah tapi user sudah dihapus: perlakukan sebagai sesi tidak sah.
    if (user == null) {
      throw const ApiException(
        401,
        'Token tidak valid atau sudah kedaluwarsa. Silakan login ulang.',
        code: 'unauthorized',
      );
    }
    // Ditangguhkan setelah token dibuat: token lama tidak boleh tetap jalan.
    if (!user.isActive) {
      throw const ApiException(
        403,
        'Akun ini ditangguhkan. Hubungi admin Food Rescue.',
        code: 'account_suspended',
      );
    }
    return ApiResponse.ok({'user': publicUser(user)});
  });

  router.get('/auth/me', meHandler);

  /// Ubah nama dan/atau email sendiri.
  ///
  /// Role, id, dan password **tidak** bisa diubah di sini: role hanya lewat
  /// seed CLI, password butuh alur reset tersendiri.
  router.patch(
    '/auth/me',
    authGuard(jwt)((Request request) async {
      final auth = authenticatedUser(request);
      final body = await readJsonObject(request);

      // Field yang tidak boleh diubah lewat endpoint ini ditolak terang-terangan
      // (bukan diabaikan diam-diam): klien yang mengira berhasil menaikkan
      // perannya sendiri harus tahu bahwa itu tidak terjadi.
      const forbidden = {'role', 'password', 'passwordHash', 'id'};
      final attempted = forbidden.where(body.containsKey).toList();
      if (attempted.isNotEmpty) {
        throw ApiException(
          422,
          'Field tidak bisa diubah dari sini: ${attempted.join(', ')}.',
          code: 'immutable_field',
        );
      }

      final user = await (db.select(db.users)
            ..where((t) => t.id.equals(auth.id)))
          .getSingleOrNull();
      if (user == null) {
        throw const ApiException(
          401,
          'Sesi tidak valid. Silakan login ulang.',
          code: 'unauthorized',
        );
      }

      var name = user.name;
      if (body.containsKey('name')) {
        name = requireString(body, 'name', maxLength: 120);
      }

      var email = user.email;
      if (body.containsKey('email')) {
        email = normalizeEmail(requireString(body, 'email', maxLength: 254));
        if (!isValidEmail(email)) {
          throw const ApiException(
            422,
            'Format email tidak valid.',
            code: 'invalid_email',
          );
        }
        if (email != user.email) {
          final taken = await (db.select(db.users)
                ..where((t) => t.email.equals(email)))
              .getSingleOrNull();
          if (taken != null) {
            throw const ApiException(
              409,
              'Email sudah dipakai akun lain.',
              code: 'email_taken',
            );
          }
        }
      }

      final updated = user.copyWith(name: name, email: email);
      await db.update(db.users).replace(updated);

      return ApiResponse.ok({'user': publicUser(updated)});
    }),
  );

  /// Ubah password sendiri. Password lama **wajib** dikirim dan diverifikasi.
  ///
  /// Tanpa verifikasi password lama, siapa pun yang menemukan perangkat yang
  /// masih login bisa mengambil alih akun secara permanen.
  router.post(
    '/auth/change-password',
    authGuard(jwt)((Request request) async {
      final auth = authenticatedUser(request);
      final body = await readJsonObject(request);

      final currentPassword = requireString(body, 'currentPassword');
      final newPassword = requireString(body, 'newPassword');

      if (!PasswordHasher.isLengthValid(newPassword)) {
        throw ApiException(
          422,
          'Password baru harus ${PasswordHasher.minLength}–'
          '${PasswordHasher.maxLengthBytes} byte.',
          code: 'invalid_password',
        );
      }

      final user = await (db.select(db.users)
            ..where((t) => t.id.equals(auth.id)))
          .getSingleOrNull();
      if (user == null) {
        throw const ApiException(
          401,
          'Sesi tidak valid. Silakan login ulang.',
          code: 'unauthorized',
        );
      }

      if (!hasher.verify(currentPassword, user.passwordHash)) {
        // 422, bukan 401: token-nya masih sah, hanya isian form yang salah.
        throw const ApiException(
          422,
          'Password lama tidak cocok.',
          code: 'wrong_password',
        );
      }

      if (currentPassword == newPassword) {
        throw const ApiException(
          422,
          'Password baru harus berbeda dari password lama.',
          code: 'same_password',
        );
      }

      await db.update(db.users).replace(
            user.copyWith(passwordHash: hasher.hash(newPassword)),
          );

      return ApiResponse.ok({
        'message': 'Password berhasil diubah. Gunakan password baru saat '
            'login berikutnya.',
      });
    }),
  );

  return router;
}

/// Email disimpan lowercase supaya `Budi@x.com` dan `budi@x.com` tidak
/// menjadi dua akun berbeda.
String normalizeEmail(String email) => email.trim().toLowerCase();

/// Validasi sengaja longgar: satu `@`, ada titik di domain, tanpa spasi.
/// Verifikasi sebenarnya tetap lewat email, bukan regex.
bool isValidEmail(String email) {
  if (email.length < 3 || email.length > 254) return false;
  if (email.contains(' ')) return false;
  final at = email.indexOf('@');
  if (at <= 0 || at != email.lastIndexOf('@')) return false;
  final domain = email.substring(at + 1);
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.');
}

UserRole _selfServiceRole(Object? raw) {
  if (raw == null) return UserRole.buyer;
  if (raw is! String) {
    throw const ApiException(422, 'Field "role" harus teks.', code: 'invalid_role');
  }
  final role = raw.trim().toLowerCase();
  return switch (role) {
    'buyer' => UserRole.buyer,
    'merchant' => UserRole.merchant,
    'admin' => throw const ApiException(
        403,
        'Akun admin tidak bisa didaftarkan lewat endpoint ini.',
        code: 'role_not_allowed',
      ),
    _ => throw const ApiException(
        422,
        'Role harus "buyer" atau "merchant".',
        code: 'invalid_role',
      ),
  };
}

/// Bentuk user yang boleh keluar ke klien. `passwordHash` **tidak pernah**
/// ikut, di endpoint mana pun. Implementasinya di `mappers.dart` supaya hanya
/// ada satu definisi.
Map<String, dynamic> publicUser(User user) => userJson(user);
