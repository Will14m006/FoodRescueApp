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

  String get formattedOriginalPrice => _rupiah(originalPrice);

  String get formattedDiscountPrice => _rupiah(discountPrice);

  String _rupiah(int value) {
    final buffer = StringBuffer();
    final chars = value.toString().split('').reversed.toList();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }
}
