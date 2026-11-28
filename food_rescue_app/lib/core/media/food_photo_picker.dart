import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil pilih foto: bytes + tipe MIME yang cocok dengan header HTTP.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.contentType});

  final List<int> bytes;
  final String contentType;
}

/// Ambil foto menu dari galeri atau kamera, sudah dikompres.
///
/// `imageQuality: 70` dan `maxWidth: 1280` adalah kompresi yang dilakukan
/// image_picker sebelum file sampai ke aplikasi — jadi bytes yang dikirim ke
/// server sudah kecil (biasanya < 200 KB), bukan foto kamera 4 MB yang
/// ditolak batas 2 MB.
///
/// Mengembalikan `null` kalau pengguna membatalkan. Batal bukan error.
Future<PickedPhoto?> pickFoodPhoto({
  required ImageSource source,
  required ImagePicker picker,
}) async {
  final file = await picker.pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;

  return PickedPhoto(
    bytes: bytes,
    contentType: _contentTypeFor(file.name, file.mimeType),
  );
}

/// Server hanya menerima JPEG/PNG/WebP. Nama file lebih bisa dipercaya
/// daripada `mimeType` (sering null di web), tapi keduanya dicek.
String _contentTypeFor(String name, String? mimeType) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';

  // Web kadang memberi nama tanpa ekstensi tapi MIME-nya benar.
  switch (mimeType) {
    case 'image/png':
      return 'image/png';
    case 'image/webp':
      return 'image/webp';
    default:
      // Default JPEG: itulah yang dihasilkan image_picker saat kompresi.
      return 'image/jpeg';
  }
}

/// Dialog pilih sumber foto. Dipisah dari layar supaya alur yang sama dipakai
/// form tambah maupun edit makanan.
Future<PickedPhoto?> showPhotoSourceSheet(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil dari kamera'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
        ],
      ),
    ),
  );

  if (source == null) return null;
  return pickFoodPhoto(source: source, picker: ImagePicker());
}
