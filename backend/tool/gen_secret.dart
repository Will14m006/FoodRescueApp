// Generator JWT_SECRET acak.
//
// Dipakai sekali saat menyiapkan `.env` lokal:
//   dart run tool/gen_secret.dart
//
// Nilai yang dicetak HANYA untuk ditempel ke `.env`. Jangan pernah
// menaruhnya di kode, dokumentasi, issue, atau chat.
import 'dart:convert';
import 'dart:math';

void main() {
  final rng = Random.secure();
  final bytes = List<int>.generate(48, (_) => rng.nextInt(256));
  // base64url tanpa padding: 64 karakter, aman untuk file .env.
  final secret = base64Url.encode(bytes).replaceAll('=', '');

  // ignore: avoid_print
  print(secret);
}
