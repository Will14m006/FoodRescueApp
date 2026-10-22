import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Hasil pengecekan izin lokasi.
enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class LocationResult {
  final Position? position;
  final LocationPermissionState permission;
  final String? errorMessage;

  const LocationResult({
    this.position,
    required this.permission,
    this.errorMessage,
  });

  bool get hasPosition => position != null;
}

abstract class LocationRepository {
  /// Minta izin (kalau belum) lalu ambil posisi. Tidak pernah melempar —
  /// semua kegagalan dikembalikan sebagai [LocationResult] supaya UI bisa
  /// menampilkan pesan izin yang jelas.
  Future<LocationResult> getCurrentPosition();
  Future<bool> openAppSettings();
}

/// P7 Advanced Feature #2: Lokasi (GPS).
///
/// Dipakai untuk menampilkan titik jemput terdekat dan mengurutkan katalog
/// berdasarkan jarak. Menangani semua kasus izin:
///   - GPS mati          -> serviceDisabled
///   - izin ditolak      -> denied
///   - ditolak permanen  -> deniedForever (+ arahkan ke Settings)
class GeolocatorLocationRepository implements LocationRepository {
  @override
  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          permission: LocationPermissionState.serviceDisabled,
          errorMessage: 'GPS belum aktif. Nyalakan lokasi di perangkat kamu.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult(
          permission: LocationPermissionState.denied,
          errorMessage: 'Izin lokasi ditolak. Kamu tetap bisa memesan tanpa lokasi.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          permission: LocationPermissionState.deniedForever,
          errorMessage:
              'Izin lokasi diblokir permanen. Aktifkan lewat pengaturan aplikasi.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationResult(
        position: position,
        permission: LocationPermissionState.granted,
      );
    } on Exception catch (e) {
      return LocationResult(
        permission: LocationPermissionState.denied,
        errorMessage: 'Gagal mengambil lokasi: $e',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

/// State lokasi user. Null = belum diminta / belum ada.
class LocationNotifier extends AsyncNotifier<LocationResult?> {
  @override
  LocationResult? build() => null;

  Future<void> request() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(locationRepositoryProvider).getCurrentPosition(),
    );
  }

  Future<void> openSettings() async {
    await ref.read(locationRepositoryProvider).openAppSettings();
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return GeolocatorLocationRepository();
});

final locationProvider =
    AsyncNotifierProvider<LocationNotifier, LocationResult?>(LocationNotifier.new);
