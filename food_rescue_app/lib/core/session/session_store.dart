import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_role.dart';
import '../../repositories/auth_repository.dart';

/// Sesi login yang disimpan di perangkat.
///
/// Yang disimpan **hanya** token dan profil ringkas — password tidak pernah
/// ikut tersimpan.
class StoredSession {
  final String token;
  final int id;
  final String name;
  final String email;
  final UserRole role;

  const StoredSession({
    required this.token,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory StoredSession.fromUser(AuthUser user) => StoredSession(
        token: user.token,
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      );
}

/// Penyimpanan sesi. SharedPreferences **bukan** tempat rahasia: token di sini
/// hanya bernilai sampai `JWT_TTL_MINUTES`, dan backend tetap memverifikasi
/// tanda tangan setiap request.
class SessionStore {
  SessionStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'food_rescue_session';

  Future<StoredSession?> read() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;

      final token = json['token'];
      final id = json['id'];
      if (token is! String || token.isEmpty || id is! int) return null;

      return StoredSession(
        token: token,
        id: id,
        name: json['name'] as String? ?? 'Pengguna',
        email: json['email'] as String? ?? '',
        role: UserRole.fromName(json['role'] as String?),
      );
    } on FormatException {
      // Data rusak/korup: anggap belum login, jangan crash saat start.
      return null;
    }
  }

  Future<void> write(StoredSession session) {
    return _prefs.setString(
      _key,
      jsonEncode({
        'token': session.token,
        'id': session.id,
        'name': session.name,
        'email': session.email,
        'role': session.role.name,
      }),
    );
  }

  Future<void> clear() => _prefs.remove(_key);
}
