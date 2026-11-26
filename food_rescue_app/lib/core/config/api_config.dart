import 'package:flutter/foundation.dart';

/// Alamat backend.
///
/// Diubah saat build, bukan di dalam kode:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
///
/// Default menyesuaikan platform supaya `flutter run` langsung nyambung:
///   - emulator Android : `10.0.2.2` (alias host dari dalam emulator)
///   - lainnya          : `127.0.0.1`
///
/// HTTP polos hanya boleh saat development. Produksi wajib HTTPS di belakang
/// reverse proxy.
abstract class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return _defaultBaseUrl;
  }

  static String get _defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }
}
