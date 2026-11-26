import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bukti foto pengambilan — **hanya lokal**.
///
/// Backend tidak menyimpan gambar (dan sebaiknya tidak: foto pelanggan di
/// server SQLite satu file = risiko kebocoran yang tidak sebanding).
/// Yang tersimpan di sini hanya pemetaan `id pesanan -> base64 foto`.
class ProofPhotoStore {
  ProofPhotoStore({SharedPreferencesAsync? prefs, this.userId})
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  final int? userId;

  static String keyFor(int? userId) =>
      userId == null ? 'fr_proof_guest' : 'fr_proof_u$userId';

  String get _key => keyFor(userId);

  Future<Map<String, String>> loadAll() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  Future<String?> read(int orderId) async => (await loadAll())['$orderId'];

  Future<void> save(int orderId, String base64Photo) async {
    final all = await loadAll();
    all['$orderId'] = base64Photo;
    await _prefs.setString(_key, jsonEncode(all));
  }

  Future<void> clear() => _prefs.remove(_key);
}
