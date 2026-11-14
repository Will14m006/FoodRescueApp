import '../core/utils/formatters.dart';

/// Kategori makanan surplus untuk filter di katalog.
enum FoodCategory {
  all('Semua'),
  bakery('Roti & Bakery'),
  main('Makanan Berat'),
  snack('Snack & Pastry'),
  drink('Minuman');

  const FoodCategory(this.label);
  final String label;
}

/// Dilempar ketika JSON dari API tidak sesuai kontrak model.
///
/// Dipakai oleh unit test "model invalid" dan "JSON rusak".
class InvalidModelException implements Exception {
  const InvalidModelException(this.message);
  final String message;

  @override
  String toString() => 'Data dari server tidak valid: $message';
}

class SurplusFood {
  final String id;
  final String merchantName;
  final String name;
  final String description;
  final int originalPrice;
  final int discountPrice;
  final int quota;
  final String pickupWindow;
  final double rating;
  final int sold;
  final FoodCategory category;
  final String emoji;

  const SurplusFood({
    required this.id,
    required this.merchantName,
    required this.name,
    required this.description,
    required this.originalPrice,
    required this.discountPrice,
    required this.quota,
    required this.pickupWindow,
    required this.category,
    this.rating = 4.8,
    this.sold = 0,
    this.emoji = '🍽️',
  });

  bool get isAvailable => quota > 0;

  /// Persentase diskon, misal 62 (%) dari Rp 40.000 -> Rp 15.000.
  int get discountPercent {
    if (originalPrice <= 0) return 0;
    return ((1 - discountPrice / originalPrice) * 100).round();
  }

  String get formattedOriginalPrice => Formatters.rupiah(originalPrice);

  String get formattedDiscountPrice => Formatters.rupiah(discountPrice);

  /// Mapping dari JSON API (dummyjson `/products/category/groceries`).
  ///
  /// Melempar [InvalidModelException] kalau field wajib tidak ada atau
  /// tipenya salah — supaya data rusak tidak diam-diam jadi objek kosong.
  factory SurplusFood.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final price = json['price'];
    final stock = json['stock'];

    if (id == null) throw const InvalidModelException('field "id" tidak ada');
    if (title is! String || title.trim().isEmpty) {
      throw const InvalidModelException('field "title" kosong / bukan teks');
    }
    if (price is! num) {
      throw const InvalidModelException('field "price" bukan angka');
    }
    if (stock is! int) {
      throw const InvalidModelException('field "stock" bukan bilangan bulat');
    }

    // Harga API dalam USD -> dikonversi ke rupiah untuk tampilan aplikasi.
    final original = (price * _usdToIdr).round();
    final discount = (json['discountPercentage'] as num?)?.toDouble() ?? 0;
    final discounted = (original * (1 - discount / 100)).round();
    final category = _categoryFor(json['category'] as String?);

    return SurplusFood(
      id: id.toString(),
      merchantName: _merchantFor(json['category'] as String?),
      name: title,
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? json['description'] as String
          : 'Makanan surplus siap diselamatkan hari ini.',
      originalPrice: original,
      discountPrice: discounted,
      // P10 fix #5: kuota = stok nyata dari API. Dulu nilainya dikarang
      // (`1 + stock % ceiling`) sehingga angka "sisa porsi" tidak pernah
      // cocok dengan ketersediaan sebenarnya.
      quota: stock < 0 ? 0 : stock,
      pickupWindow: _pickupWindowFor(id is int ? id : 0),
      category: category,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      sold: (json['reviews'] as List?)?.length ?? 0,
      emoji: _emojiFor(json['category'] as String?, title),
    );
  }

  /// Salinan dengan kuota berkurang setelah pesanan berhasil.
  ///
  /// P10 fix #5: katalog ikut diperbarui supaya angka sisa porsi tidak
  /// "beku" setelah user memesan.
  SurplusFood copyWithQuota(int newQuota) {
    return SurplusFood(
      id: id,
      merchantName: merchantName,
      name: name,
      description: description,
      originalPrice: originalPrice,
      discountPrice: discountPrice,
      quota: newQuota < 0 ? 0 : newQuota,
      pickupWindow: pickupWindow,
      category: category,
      rating: rating,
      sold: sold,
      emoji: emoji,
    );
  }

  static const _usdToIdr = 16000;

  static String _merchantFor(String? category) {
    switch (category) {
      case 'groceries':
        return 'Food Rescue Market';
      case 'fruits':
        return 'Kebun Segar';
      default:
        return 'Mitra Food Rescue';
    }
  }

  static FoodCategory _categoryFor(String? category) {
    switch (category) {
      case 'groceries':
        return FoodCategory.main;
      case 'fruits':
        return FoodCategory.snack;
      default:
        return FoodCategory.main;
    }
  }

  /// Jam ambil **placeholder demo**.
  ///
  /// P10 fix #5: dummyjson tidak menyediakan jam operasional merchant, jadi
  /// nilai ini tetap diturunkan dari id produk dan ditandai sebagai estimasi
  /// di UI — bukan diklaim sebagai jadwal asli.
  static String _pickupWindowFor(int id) {
    const windows = [
      '17:00 - 19:00',
      '18:00 - 20:00',
      '19:00 - 21:00',
      '20:00 - 22:00',
    ];
    return windows[id % windows.length];
  }

  static String _emojiFor(String? category, String title) {
    final lower = title.toLowerCase();
    if (lower.contains('apple') || lower.contains('kiwi')) return '🍎';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('juice')) return '🥤';
    if (lower.contains('coffee')) return '☕';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('meat') || lower.contains('steak')) return '🍖';
    if (lower.contains('fish')) return '🐟';
    if (category == 'groceries') return '🛒';
    return '🍽️';
  }
}
