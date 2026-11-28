import 'dart:io';

import 'package:food_rescue_backend/app.dart';
import 'package:food_rescue_backend/auth/jwt_service.dart';
import 'package:food_rescue_backend/auth/login_throttle.dart';
import 'package:food_rescue_backend/auth/password_hasher.dart';
import 'package:food_rescue_backend/config.dart';
import 'package:food_rescue_backend/db/database.dart';
import 'package:food_rescue_backend/media/photo_store.dart';

void logLine(String message) {
  // Timestamp ISO-8601 UTC: mudah dibaca mesin maupun manusia.
  // Tidak pernah mencetak nilai konfigurasi rahasia.
  stdout.writeln('[${DateTime.now().toUtc().toIso8601String()}] $message');
}

Future<void> main(List<String> args) async {
  final AppConfig config;
  try {
    config = AppConfig.load();
  } on FormatException catch (e) {
    logLine('KONFIGURASI GAGAL: ${e.message}');
    exitCode = 78; // EX_CONFIG
    return;
  }

  final dbFile = File(config.databaseFile);
  dbFile.parent.createSync(recursive: true);

  final db = AppDatabase.open(config);
  final jwt = JwtService(secret: config.jwtSecret, ttl: config.jwtTtl);
  final hasher = PasswordHasher(cost: config.bcryptCost);
  final photos = PhotoStore(directory: config.uploadDirectory);
  Directory(config.uploadDirectory).createSync(recursive: true);

  // Bind ke loopback: server lokal tidak boleh terbuka ke jaringan sekitar
  // secara default. Untuk mengakses dari HP di Wi-Fi yang sama, ubah secara
  // sadar lewat argumen:
  //   dart run bin/server.dart --host 0.0.0.0
  final host = _flag(args, '--host') ?? '127.0.0.1';

  final handler = buildHandler(
    log: logLine,
    db: db,
    jwt: jwt,
    hasher: hasher,
    throttle: LoginThrottle(),
    photos: photos,
    corsOrigins: config.corsOrigins,
  );

  final server = await serve(host: host, port: config.port, handler: handler);

  logLine('Food Rescue API siap di http://$host:${server.port}');
  logLine('Konfigurasi: ${config.describe()}');

  // Matikan dengan rapi supaya koneksi & database tidak tertinggal.
  Future<void> shutdown() async {
    await server.close(force: true);
    await db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) {
    logLine('Menerima SIGINT, mematikan server...');
    shutdown();
  });
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => shutdown());
  }
}

/// Membaca `--flag nilai` sederhana tanpa menambah dependency arg parser.
String? _flag(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
