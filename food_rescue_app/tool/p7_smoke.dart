// Smoke test manual advanced feature P7 (bukan unit test).
// Jalankan: dart run tool/p7_smoke.dart
// ignore_for_file: avoid_print
import 'package:food_rescue_app/repositories/auth_repository.dart';

Future<void> main() async {
  final repo = ApiAuthRepository();

  final user = await repo.login(username: 'emilys', password: 'emilyspass');
  print('AUTH sukses  -> ${user.name} <${user.email}>');
  print('Token        -> ${user.token.substring(0, 18)}...');

  try {
    await repo.login(username: 'emilys', password: 'password-salah');
    print('AUTH gagal   -> TIDAK terduga (harusnya error)');
  } on AuthException catch (e) {
    print('AUTH ditolak -> ${e.message}');
  }
}
