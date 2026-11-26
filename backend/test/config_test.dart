import 'package:food_rescue_backend/config.dart';
import 'package:test/test.dart';

/// Semua nilai rahasia di file ini SINTETIS dan hanya dipakai test.
const _validSecret = 'test-only-secret-0123456789abcdef0123456789abcdef';

AppConfig _config({String secret = _validSecret, String db = 'data/test.db'}) {
  return AppConfig(
    port: 8080,
    jwtSecret: secret,
    jwtTtl: const Duration(minutes: 60),
    databaseFile: db,
    logSql: false,
  );
}

void main() {
  group('AppConfig.validate — kunci keamanan', () {
    test('menerima secret acak yang cukup panjang', () {
      expect(() => _config().validate(), returnsNormally);
    });

    test('menolak secret kosong', () {
      expect(
        () => _config(secret: '').validate(),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak secret masih berisi placeholder .env.example', () {
      expect(
        () => _config(secret: 'ganti-dengan-hasil-gen_secret-dart').validate(),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak secret kurang dari 32 karakter', () {
      expect(
        () => _config(secret: 'pendek-sekali').validate(),
        throwsA(isA<FormatException>()),
      );
    });

    test('menolak DATABASE_FILE kosong', () {
      expect(
        () => _config(db: '   ').validate(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AppConfig.describe', () {
    test('tidak pernah mencetak nilai JWT_SECRET', () {
      final text = _config().describe();
      expect(text.contains(_validSecret), isFalse);
      expect(text.contains('<dijaga>'), isTrue);
    });

    test('toString juga tidak membocorkan secret', () {
      expect(_config().toString().contains(_validSecret), isFalse);
    });
  });
}
