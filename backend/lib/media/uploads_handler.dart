import 'dart:io';

import 'package:shelf/shelf.dart';

import '../media/photo_store.dart';
import '../middleware/api_response.dart';

/// Menyajikan satu foto menu dari `data/uploads/`.
///
/// Hanya nama file yang lolos [PhotoStore.isSafeName] yang dilayani. Ini
/// penting: tanpa filter, `/uploads/../../.env` akan membaca file di luar
/// folder upload. `shelf_static` sengaja tidak dipakai — satu dependency
/// tambahan untuk 30 baris yang harus dikunci dengan ketat.
Future<Response> serveUpload({
  required String directory,
  required String? name,
}) async {
  if (name == null || !PhotoStore.isSafeName(name)) {
    throw const ApiException(404, 'Foto tidak ditemukan.');
  }

  final file = File('$directory${Platform.pathSeparator}$name');
  if (!await file.exists()) {
    throw const ApiException(404, 'Foto tidak ditemukan.');
  }

  final contentType = switch (name.split('.').last) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  return Response.ok(
    file.openRead(),
    headers: {
      'content-type': contentType,
      // Nama file acak & isinya tidak pernah berubah → aman di-cache lama.
      // Ini yang membuat katalog tidak memuat ulang foto setiap scroll.
      'cache-control': 'public, max-age=31536000, immutable',
      'content-length': '${await file.length()}',
    },
  );
}
