// Membuat akun admin + data demo.
//
// Dijalankan DI MESIN SERVER, bukan lewat HTTP:
//   dart run tool/seed.dart --email admin@foodrescue.id --name "Admin"
//
// Kenapa bukan endpoint? Karena endpoint register yang menerima `role=admin`
// berarti siapa pun yang menemukannya bisa menjadi admin. Password dibaca dari
// argumen `--password` atau, lebih aman, dari environment `SEED_PASSWORD`.
//
// Aman dijalankan berulang: kalau email sudah ada, perannya dinaikkan menjadi
// admin dan passwordnya diganti (dibutuhkan saat lupa password admin).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:food_rescue_backend/auth/password_hasher.dart';
import 'package:food_rescue_backend/config.dart';
import 'package:food_rescue_backend/db/database.dart';
import 'package:food_rescue_backend/routes/auth_routes.dart';

const _demoStore = 'Warung Bu Siti';
const _demoBuyerEmail = 'buyer@foodrescue.id';
const _demoMerchantEmail = 'toko@foodrescue.id';
const _demoPassword = 'DemoFood123';

void logLine(String message) => stdout.writeln(message);

Future<void> main(List<String> args) async {
  final email = (_flag(args, '--email') ?? 'admin@foodrescue.id').trim();
  final name = _flag(args, '--name') ?? 'Admin Food Rescue';
  final password = Platform.environment['SEED_PASSWORD'] ??
      _flag(args, '--password') ??
      _promptPassword();
  final withDemo = !args.contains('--no-demo');

  if (!isValidEmail(normalizeEmail(email))) {
    logLine('Email tidak valid: $email');
    exitCode = 64; // EX_USAGE
    return;
  }
  if (!PasswordHasher.isLengthValid(password)) {
    logLine(
      'Password harus ${PasswordHasher.minLength}-${PasswordHasher.maxLengthBytes} byte.',
    );
    exitCode = 64;
    return;
  }

  final AppConfig config;
  try {
    config = AppConfig.load();
  } on FormatException catch (e) {
    logLine('KONFIGURASI GAGAL: ${e.message}');
    exitCode = 78;
    return;
  }

  File(config.databaseFile).parent.createSync(recursive: true);
  final db = AppDatabase.open(config);
  final hasher = PasswordHasher(cost: config.bcryptCost);

  try {
    final adminEmail = normalizeEmail(email);
    final existing = await (db.select(db.users)
          ..where((t) => t.email.equals(adminEmail)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.users).insert(
            UsersCompanion.insert(
              email: adminEmail,
              passwordHash: hasher.hash(password),
              name: name,
              role: UserRole.admin,
            ),
          );
      logLine('Admin dibuat: $adminEmail');
    } else {
      await db.update(db.users).replace(
            existing.copyWith(
              role: UserRole.admin,
              passwordHash: hasher.hash(password),
            ),
          );
      logLine('Akun $adminEmail dinaikkan/diperbarui menjadi admin.');
    }

    if (withDemo) await _seedDemo(db, hasher);

    logLine('Selesai. Database: ${config.databaseFile}');
  } finally {
    await db.close();
  }
}

/// Data contoh supaya aplikasi tidak kosong saat demo.
///
/// Membuat pembeli, satu merchant + toko, dan tiga makanan dengan kuota
/// berbeda (termasuk satu yang kuotanya 1 untuk mendemokan aturan kuota).
Future<void> _seedDemo(AppDatabase db, PasswordHasher hasher) async {
  final buyer = await _ensureUser(
    db,
    hasher,
    email: _demoBuyerEmail,
    name: 'Budi Pembeli',
    role: UserRole.buyer,
  );
  final merchantUser = await _ensureUser(
    db,
    hasher,
    email: _demoMerchantEmail,
    name: 'Siti Mitra',
    role: UserRole.merchant,
  );

  final merchant = await (db.select(db.merchants)
        ..where((t) => t.ownerId.equals(merchantUser.id)))
      .getSingleOrNull() ??
      await db.into(db.merchants).insertReturning(
            MerchantsCompanion.insert(
              storeName: _demoStore,
              ownerId: merchantUser.id,
            ),
          );

  final existingFoods = await (db.select(db.surplusFoods)
        ..where((t) => t.merchantId.equals(merchant.id)))
      .get();
  if (existingFoods.isNotEmpty) {
    logLine('Data demo sudah ada (${existingFoods.length} makanan), dilewati.');
    return;
  }

  final menu = [
    (name: 'Nasi Goreng Sisa', original: 25000, discount: 9000, quota: 4),
    (name: 'Roti Bakar Keju', original: 18000, discount: 6000, quota: 1),
    (name: 'Es Teh Manis', original: 8000, discount: 3000, quota: 10),
  ];

  for (final item in menu) {
    await db.into(db.surplusFoods).insert(
          SurplusFoodsCompanion.insert(
            merchantId: merchant.id,
            name: item.name,
            description: const Value('Surplus layak konsumsi hari ini.'),
            originalPrice: item.original,
            discountPrice: item.discount,
            quota: item.quota,
            pickupWindow: '19:00 - 21:00',
          ),
        );
  }

  logLine('Data demo dibuat untuk toko "$_demoStore".');
  logLine('  pembeli   : $_demoBuyerEmail / $_demoPassword');
  logLine('  merchant  : $_demoMerchantEmail / $_demoPassword');
  logLine('  (id pembeli=${buyer.id}, id merchant user=${merchantUser.id})');
}

Future<User> _ensureUser(
  AppDatabase db,
  PasswordHasher hasher, {
  required String email,
  required String name,
  required UserRole role,
}) async {
  final normalized = normalizeEmail(email);
  final existing = await (db.select(db.users)
        ..where((t) => t.email.equals(normalized)))
      .getSingleOrNull();
  if (existing != null) return existing;

  return db.into(db.users).insertReturning(
        UsersCompanion.insert(
          email: normalized,
          passwordHash: hasher.hash(_demoPassword),
          name: name,
          role: role,
        ),
      );
}

/// Password dari terminal, tanpa gema.
///
/// `stdin.echoMode` hanya bekerja saat terminal interaktif; kalau tidak bisa,
/// pemanggil harus memakai `SEED_PASSWORD` atau `--password`.
String _promptPassword() {
  try {
    stdout.write('Password admin (min 8 karakter): ');
    final previous = stdin.echoMode;
    stdin.echoMode = false;
    final value = stdin.readLineSync()?.trim() ?? '';
    stdin.echoMode = previous;
    stdout.writeln();
    return value;
  } on StdinException {
    logLine(
      'Tidak bisa membaca password dari terminal. '
      'Set SEED_PASSWORD atau pakai --password.',
    );
    exitCode = 64;
    exit(64);
  }
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
