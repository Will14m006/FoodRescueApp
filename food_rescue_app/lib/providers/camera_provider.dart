import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil pengambilan foto.
class CameraResult {
  final Uint8List? bytes;
  final String? errorMessage;
  /// True kalau user menutup kamera tanpa mengambil foto.
  final bool cancelled;

  const CameraResult({
    this.bytes,
    this.errorMessage,
    this.cancelled = false,
  });

  bool get hasPhoto => bytes != null;
}

abstract class CameraRepository {
  /// Ambil foto dari kamera. Tidak pernah melempar — semua kegagalan
  /// (izin ditolak, batal, error) dikembalikan lewat [CameraResult].
  Future<CameraResult> takePhoto();
}

/// P7 Advanced Feature #3: Kamera.
///
/// Dipakai sebagai bukti pengambilan makanan: saat menandai pesanan
/// "Sudah Pickup", user memotret makanan yang diambil.
class ImagePickerCameraRepository implements CameraRepository {
  ImagePickerCameraRepository({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CameraResult> takePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 80,
      );

      if (file == null) {
        return const CameraResult(cancelled: true);
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return const CameraResult(
          errorMessage: 'Foto kosong. Coba ambil ulang.',
        );
      }

      return CameraResult(bytes: bytes);
    } on Exception catch (e) {
      // Termasuk izin kamera ditolak (PlatformException).
      return CameraResult(
        errorMessage: 'Tidak bisa membuka kamera: $e',
      );
    }
  }
}

class CameraNotifier extends AsyncNotifier<CameraResult?> {
  @override
  CameraResult? build() => null;

  Future<void> takePhoto() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cameraRepositoryProvider).takePhoto(),
    );
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final cameraRepositoryProvider = Provider<CameraRepository>((ref) {
  return ImagePickerCameraRepository();
});

final cameraProvider =
    AsyncNotifierProvider<CameraNotifier, CameraResult?>(CameraNotifier.new);
