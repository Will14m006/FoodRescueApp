import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import '../middleware/api_response.dart';

/// Penyimpanan foto menu di disk.
///
/// Gambar **tidak** masuk SQLite: satu baris dengan blob 2 MB membuat setiap
/// backup database ikut membawa semua foto, dan SQLite bukan tempat yang baik
/// untuk itu. Yang disimpan di tabel hanya nama filenya.
///
/// Nama file dibuat acak oleh server (`Random.secure`), tidak memakai nama
/// kiriman klien — nama kiriman adalah jalan klasik untuk path traversal.
class PhotoStore {
  PhotoStore({required this.directory});

  /// Folder tempat file disimpan, mis. `data/uploads`.
  final String directory;

  /// Batas 2 MB: cukup untuk foto menu 1080p yang sudah dikompres klien,
  /// dan masih murah untuk disk server demo.
  static const maxBytes = 2 * 1024 * 1024;

  /// Diterima hanya format yang benar-benar dipakai aplikasi. SVG ditolak
  /// dengan sadar: SVG bisa memuat skrip.
  static const allowedTypes = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  static const _alphabet =
      'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Baca body biner dan simpan sebagai file baru. Mengembalikan nama file.
  ///
  /// Isi file diperiksa lewat magic bytes, bukan hanya header `Content-Type`:
  /// header bisa dikarang, isi file tidak.
  Future<String> save(Request request) async {
    final contentType =
        request.headers['content-type']?.toLowerCase().split(';').first.trim();
    final extension = allowedTypes[contentType];
    if (extension == null) {
      throw const ApiException(
        415,
        'Format foto harus JPEG, PNG, atau WebP.',
        code: 'unsupported_image_type',
      );
    }

    final declared = request.contentLength;
    if (declared != null && declared > maxBytes) {
      throw const ApiException(
        413,
        'Foto terlalu besar (maksimal 2 MB).',
        code: 'image_too_large',
      );
    }

    final bytes = await _readAll(request);
    if (bytes.isEmpty) {
      throw const ApiException(400, 'File foto kosong.', code: 'empty_image');
    }
    if (bytes.length > maxBytes) {
      throw const ApiException(
        413,
        'Foto terlalu besar (maksimal 2 MB).',
        code: 'image_too_large',
      );
    }
    if (!_looksLike(contentType!, bytes)) {
      throw const ApiException(
        422,
        'Isi file bukan gambar yang valid.',
        code: 'invalid_image',
      );
    }

    final name = '${_randomToken(24)}.$extension';
    final dir = Directory(directory);
    await dir.create(recursive: true);
    await File('${dir.path}${Platform.pathSeparator}$name').writeAsBytes(
      bytes,
      flush: true,
    );
    return name;
  }

  /// Hapus file lama bila ada. Gagal hapus **tidak** menggagalkan request:
  /// foto baru sudah tersimpan, file yatim lebih baik daripada 500.
  Future<void> deleteQuietly(String? name) async {
    if (name == null || !isSafeName(name)) return;
    try {
      final file = File('${Directory(directory).path}'
          '${Platform.pathSeparator}$name');
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Diabaikan dengan sengaja — lihat doc di atas.
    }
  }

  /// Nama file dari klien hanya boleh bentuk yang kita buat sendiri. Ini
  /// penjaga terakhir terhadap `../` dan nama absolut.
  static bool isSafeName(String name) {
    if (name.isEmpty || name.length > 64) return false;
    if (name.contains('..') || name.contains('/') || name.contains(r'\')) {
      return false;
    }
    return RegExp(r'^[a-z0-9]{1,48}\.(jpg|png|webp)$').hasMatch(name);
  }

  static Future<Uint8List> _readAll(Request request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw const ApiException(
          413,
          'Foto terlalu besar (maksimal 2 MB).',
          code: 'image_too_large',
        );
      }
    }
    return builder.takeBytes();
  }

  static bool _looksLike(String contentType, Uint8List b) {
    bool startsWith(List<int> prefix) {
      if (b.length < prefix.length) return false;
      for (var i = 0; i < prefix.length; i++) {
        if (b[i] != prefix[i]) return false;
      }
      return true;
    }

    return switch (contentType) {
      // JPEG: FF D8 FF
      'image/jpeg' => startsWith(const [0xFF, 0xD8, 0xFF]),
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      'image/png' =>
        startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      // WebP: "RIFF" .... "WEBP"
      'image/webp' =>
        startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
            b.length >= 12 &&
            b[8] == 0x57 &&
            b[9] == 0x45 &&
            b[10] == 0x42 &&
            b[11] == 0x50,
      _ => false,
    };
  }

  static String _randomToken(int length) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }
}
