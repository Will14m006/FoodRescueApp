import 'dart:io';

import 'package:shelf/shelf.dart';

/// Pembatas percobaan login, disimpan di memori proses.
///
/// Tanpa ini, `POST /auth/login` bisa di-brute-force ribuan kali per menit.
/// bcrypt memperlambat penyerang, tapi tidak membatasi jumlah percobaan.
///
/// ponytail: satu proses, satu map. Kalau API dijalankan >1 instance atau di
/// belakang load balancer, ganti dengan penyimpanan bersama (Redis) supaya
/// batasnya tetap berlaku global.
class LoginThrottle {
  LoginThrottle({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 15),
  });

  final int maxAttempts;
  final Duration window;

  final _failures = <String, _Attempts>{};

  /// Kunci per email **dan** alamat IP: penyerang tidak bisa mengunci akun
  /// orang lain hanya dengan salah password berulang kali dari jaraknya sendiri.
  static String keyFor(Request request, String email) {
    final info = request.context['shelf.io.connection_info'];
    final ip = info is HttpConnectionInfo
        ? info.remoteAddress.address
        : 'unknown';
    return '${email.toLowerCase()}|$ip';
  }

  bool isBlocked(String key, {DateTime? now}) {
    final attempts = _failures[key];
    if (attempts == null) return false;

    final current = now ?? DateTime.now();
    if (current.difference(attempts.first) >= window) {
      _failures.remove(key);
      return false;
    }
    return attempts.count >= maxAttempts;
  }

  void recordFailure(String key, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final attempts = _failures[key];
    if (attempts == null ||
        current.difference(attempts.first) >= window) {
      _failures[key] = _Attempts(first: current, count: 1);
      if (_failures.length > 1000) _prune(current);
      return;
    }
    attempts.count++;
  }

  /// Login berhasil → hitungan dihapus, user tidak terkunci karena salah
  /// ketik sebelumnya.
  void reset(String key) => _failures.remove(key);

  void _prune(DateTime now) {
    _failures.removeWhere((_, attempts) => now.difference(attempts.first) >= window);
  }
}

class _Attempts {
  _Attempts({required this.first, required this.count});

  final DateTime first;
  int count;
}
