import '../core/network/api_exception.dart';
import '../core/utils/formatters.dart';

/// Kategori makanan surplus untuk filter di katalog.
///
/// Backend tidak menyimpan kategori (tabel `SurplusFoods` hanya punya nama),
/// jadi kategorinya diturunkan dari nama. Tujuannya semata membantu penyaringan
/// di UI, bukan data bisnis.
enum FoodCategory {
  all('Semua'),
  bakery('Roti & Bakery'),
  main('Makanan Berat'),
  snack('Snack & Pastry'),
  drink('Minuman');

  const FoodCategory(this.label);
  final String label;
}

class SurplusFood {
  final int id;
  final int merchantId;
  final String merchantName;
  final String name;
  final String description;
  final int originalPrice;
  final int discountPrice;
  final int quota;
  final String pickupWindow;
  final bool isActive;
  final FoodCategory category;
  final String emoji;

  /// Path foto dari server (`/uploads/x.jpg`), null = pakai gambar bawaan
  /// sesuai kategori. Disimpan relatif supaya host boleh berubah.
  final String? imageUrl;

  const SurplusFood({
    required this.id,
    required this.merchantName,
    required this.name,
    required this.description,
    required this.originalPrice,
    required this.discountPrice,
    required this.quota,
    required this.pickupWindow,
    this.merchantId = 0,
    this.isActive = true,
    this.category = FoodCategory.main,
    this.emoji = '🍽️',
    this.imageUrl,
  });

  bool get isAvailable => isActive && quota > 0;

  /// Persentase diskon, misal 62 (%) dari Rp 40.000 -> Rp 15.000.
  int get discountPercent {
    if (originalPrice <= 0) return 0;
    return ((1 - discountPrice / originalPrice) * 100).round();
  }

  String get formattedOriginalPrice => Formatters.rupiah(originalPrice);

  String get formattedDiscountPrice => Formatters.rupiah(discountPrice);

  /// Mapping dari `GET /foods`.
  ///
  /// Melempar [ApiException] kalau field wajib hilang atau tipenya salah —
  /// data rusak tidak boleh diam-diam menjadi objek kosong.
  factory SurplusFood.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final originalPrice = json['originalPrice'];
    final discountPrice = json['discountPrice'];
    final quota = json['quota'];

    if (id is! int) throw const ApiException('Field "id" makanan tidak valid.');
    if (name is! String || name.trim().isEmpty) {
      throw const ApiException('Nama makanan kosong.');
    }
    if (originalPrice is! int || discountPrice is! int) {
      throw const ApiException('Harga makanan tidak valid.');
    }
    if (quota is! int || quota < 0) {
      throw const ApiException('Kuota makanan tidak valid.');
    }

    return SurplusFood(
      id: id,
      merchantId: json['merchantId'] as int? ?? 0,
      merchantName:
          (json['merchantName'] as String?)?.trim().isNotEmpty == true
              ? json['merchantName'] as String
              : 'Mitra Food Rescue',
      name: name.trim(),
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? (json['description'] as String).trim()
          : 'Makanan surplus siap diselamatkan hari ini.',
      originalPrice: originalPrice,
      discountPrice: discountPrice,
      quota: quota,
      pickupWindow: (json['pickupWindow'] as String?)?.trim().isNotEmpty == true
          ? (json['pickupWindow'] as String).trim()
          : 'Lihat di toko',
      isActive: json['isActive'] as bool? ?? true,
      category: _categoryFor(name),
      emoji: _emojiFor(name),
      imageUrl: (json['imageUrl'] as String?)?.trim().isNotEmpty == true
          ? (json['imageUrl'] as String).trim()
          : null,
    );
  }

  /// Salinan dengan kuota berkurang setelah pesanan berhasil.
  SurplusFood copyWithQuota(int newQuota) {
    return SurplusFood(
      id: id,
      merchantId: merchantId,
      merchantName: merchantName,
      name: name,
      description: description,
      originalPrice: originalPrice,
      discountPrice: discountPrice,
      quota: newQuota < 0 ? 0 : newQuota,
      pickupWindow: pickupWindow,
      isActive: isActive,
      category: category,
      emoji: emoji,
      imageUrl: imageUrl,
    );
  }

  static FoodCategory _categoryFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('roti') ||
        lower.contains('bakery') ||
        lower.contains('donat') ||
        lower.contains('croissant')) {
      return FoodCategory.bakery;
    }
    if (lower.contains('jus') ||
        lower.contains('teh') ||
        lower.contains('kopi') ||
        lower.contains('minum') ||
        lower.contains('susu')) {
      return FoodCategory.drink;
    }
    if (lower.contains('pastry') || lower.contains('snack')) {
      return FoodCategory.snack;
    }
    return FoodCategory.main;
  }

  static String _emojiFor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nasi')) return '🍚';
    if (lower.contains('mie') || lower.contains('bakmi')) return '🍜';
    if (lower.contains('roti') || lower.contains('donat')) return '🍞';
    if (lower.contains('jus') || lower.contains('minum')) return '🥤';
    if (lower.contains('teh') || lower.contains('kopi')) return '☕';
    if (lower.contains('ayam')) return '🍗';
    if (lower.contains('ikan')) return '🐟';
    if (lower.contains('buah')) return '🍎';
    return '🍽️';
  }
}
