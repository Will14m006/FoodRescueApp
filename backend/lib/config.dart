import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Konfigurasi runtime yang dibaca dari `.env`.
///
/// Aturan keras (lihat `validate()`):
///   - `JWT_SECRET` wajib ada, minimal 32 karakter, dan bukan placeholder.
///   - Tidak ada nilai default yang aman untuk secret — lebih baik server
///     gagal start daripada berjalan dengan token yang bisa dipalsukan.
class AppConfig {
  const AppConfig({
    required this.port,
    required this.jwtSecret,
    required this.jwtTtl,
    required this.databaseFile,
    required this.logSql,
    required this.bcryptCost,
    this.uploadDirectory = 'data/uploads',
    this.corsOrigins = const [],
  });

  final int port;
  final String jwtSecret;
  final Duration jwtTtl;
  final String databaseFile;
  final bool logSql;

  /// Folder foto menu. Default `data/uploads`, sejajar dengan file database.
  final String uploadDirectory;

  /// Origin yang boleh memanggil API dari browser. Kosong = CORS mati
  /// (default aman: client Android tidak butuh CORS).
  final List<String> corsOrigins;

  /// Log2 jumlah putaran bcrypt. 12 ≈ 320 ms di mesin dev.
  final int bcryptCost;

  /// Placeholder yang ada di `.env.example`. Kalau masih terpakai berarti
  /// developer lupa menyalin/mengisi `.env`.
  static const _placeholderSecrets = {
    'ganti-dengan-hasil-gen_secret-dart',
  };

  static AppConfig load({String? envPath}) {
    final env = DotEnv(includePlatformEnvironment: true);
    final candidates = <String>[
      if (envPath != null) envPath,
      '.env',
      '../.env',
    ];

    // Muat file pertama yang ada. Kalau tidak ada file sama sekali, tetap
    // jalan: nilainya bisa datang dari environment variable proses
    // (mis. CI atau container), atau validate() akan menolak.
    for (final path in candidates) {
      if (File(path).existsSync()) {
        env.load([path]);
        break;
      }
    }

    String? read(String key) => env[key]?.trim();

    final port = int.tryParse(read('PORT') ?? '') ?? 8080;
    if (port < 1 || port > 65535) {
      throw const FormatException('PORT di .env tidak valid (1-65535).');
    }

    final ttlMinutes = int.tryParse(read('JWT_TTL_MINUTES') ?? '') ?? 60;
    if (ttlMinutes < 1 || ttlMinutes > 60 * 24 * 30) {
      throw const FormatException(
        'JWT_TTL_MINUTES tidak wajar (1 .. 43200 menit).',
      );
    }

    final config = AppConfig(
      port: port,
      jwtSecret: read('JWT_SECRET') ?? '',
      jwtTtl: Duration(minutes: ttlMinutes),
      databaseFile: read('DATABASE_FILE') ?? 'data/food_rescue.db',
      logSql: (read('LOG_SQL') ?? 'false').toLowerCase() == 'true',
      bcryptCost: int.tryParse(read('BCRYPT_COST') ?? '') ?? 12,
      uploadDirectory: read('UPLOAD_DIR') ?? 'data/uploads',
      corsOrigins: (read('CORS_ORIGINS') ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );

    config.validate();
    return config;
  }

  /// Gagal cepat dengan pesan yang jelas. Dipanggil dari `load()` dan juga
  /// bisa diuji langsung.
  void validate() {
    if (jwtSecret.isEmpty) {
      throw const FormatException(
        'JWT_SECRET belum diisi. Salin .env.example menjadi .env lalu isi '
        'dengan hasil `dart run tool/gen_secret.dart`.',
      );
    }
    if (_placeholderSecrets.contains(jwtSecret)) {
      throw const FormatException(
        'JWT_SECRET masih berisi nilai contoh dari .env.example. '
        'Jalankan `dart run tool/gen_secret.dart` dan ganti nilainya.',
      );
    }
    if (jwtSecret.length < 32) {
      throw const FormatException(
        'JWT_SECRET terlalu pendek (minimal 32 karakter). '
        'Gunakan `dart run tool/gen_secret.dart`.',
      );
    }
    if (databaseFile.trim().isEmpty) {
      throw const FormatException('DATABASE_FILE tidak boleh kosong.');
    }
    if (bcryptCost < 10 || bcryptCost > 15) {
      throw const FormatException(
        'BCRYPT_COST di luar batas aman (10..15). Nilai kecil membuat hash '
        'mudah dipecahkan, nilai besar membuat login lambat.',
      );
    }
  }

  /// Versi aman untuk dicetak ke log: tidak pernah memuat secret.
  String describe() => 'port=$port, db=$databaseFile, '
      'jwtTtl=${jwtTtl.inMinutes}m, jwtSecret=<dijaga>, logSql=$logSql, '
      'bcryptCost=$bcryptCost, cors=${corsOrigins.isEmpty ? 'mati' : corsOrigins.join('|')}';

  @override
  String toString() => 'AppConfig(${describe()})';
}
