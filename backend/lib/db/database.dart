import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../config.dart';

part 'database.g.dart';

/// Peran user. Disimpan sebagai teks ("buyer"/"merchant"/"admin") supaya
/// migrasi nanti tidak bergantung pada urutan enum.
enum UserRole { buyer, merchant, admin }

/// Status pesanan. Nilai teksnya lowercase (`pending`/`completed`/`cancelled`)
/// karena itu yang sudah dipakai `OrderStatusX.jsonValue` di aplikasi Flutter.
///
/// Aturan transisi (Architecture.md §6.8): hanya `pending` yang boleh berubah,
/// ke `completed` (divalidasi merchant) atau `cancelled`. Tidak ada rollback.
enum OrderStatus { pending, completed, cancelled }

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get email => text().withLength(min: 3, max: 254).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get role => textEnum<UserRole>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get storeName => text().withLength(min: 1, max: 160)();
  IntColumn get ownerId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ownerId},
      ];
}

class SurplusFoods extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get merchantId => integer().references(Merchants, #id)();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get originalPrice => integer()();
  IntColumn get discountPrice => integer()();
  IntColumn get quota => integer()();
  TextColumn get pickupWindow => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get buyerId => integer().references(Users, #id)();
  IntColumn get foodId => integer().references(SurplusFoods, #id)();
  IntColumn get quantity => integer()();
  IntColumn get totalPrice => integer()();
  TextColumn get pickupCode => text().unique()();
  TextColumn get status =>
      textEnum<OrderStatus>().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Users, Merchants, SurplusFoods, Orders])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Membuka database di file SQLite.
  ///
  /// `setup` dipakai untuk PRAGMA, bukan query: PRAGMA hanya berlaku per
  /// koneksi, jadi harus dipasang saat koneksi dibuat.
  factory AppDatabase.open(AppConfig config) {
    return AppDatabase(
      NativeDatabase.createInBackground(
        File(config.databaseFile),
        setup: (raw) {
          // WAL: baca dan tulis boleh berjalan bersamaan, jauh lebih aman
          // untuk server daripada mode journal default.
          raw.execute('PRAGMA journal_mode = WAL;');
          // SQLite mematikan FK secara default — tanpa ini, references() di
          // atas hanya dekorasi tanpa penegakan.
          raw.execute('PRAGMA foreign_keys = ON;');
          raw.execute('PRAGMA busy_timeout = 5000;');
        },
      ),
    );
  }

  /// Ganti nilai `true` sementara hanya saat debugging query.
  /// Log SQL bisa memuat data pribadi, jadi default-nya diam.
  static bool logStatements = false;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          // Diulang di sini karena koneksi hasil createInBackground bisa
          // membuat handle baru; memastikan FK tetap menyala.
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}
