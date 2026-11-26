import 'dart:io';

import 'package:food_rescue_backend/app.dart';
import 'package:food_rescue_backend/config.dart';

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

  // Bind ke loopback: server lokal tidak boleh terbuka ke jaringan sekitar
  // secara default. Untuk mengakses dari HP di Wi-Fi yang sama, ubah secara
  // sadar ke '0.0.0.0' lewat argumen:
  //   dart run bin/server.dart --host 0.0.0.0
  final host = _flag(args, '--host') ?? '127.0.0.1';

  final handler = buildHandler(logLine);
  final server = await serve(host: host, port: config.port, handler: handler);

  logLine('Food Rescue API siap di http://$host:${server.port}');
  logLine('Konfigurasi: ${config.describe()}');

  // Matikan dengan rapi supaya koneksi tidak tertinggal menggantung.
  ProcessSignal.sigint.watch().listen((_) async {
    logLine('Menerima SIGINT, mematikan server...');
    await server.close(force: true);
    exit(0);
  });
}

/// Membaca `--flag nilai` sederhana tanpa menambah dependency arg parser.
String? _flag(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
