class SurplusFood {
  final String id;
  final String merchantName;
  final String name;
  final int originalPrice;
  final int discountPrice;
  final int quota;
  final String pickupWindow;

  const SurplusFood({
    required this.id,
    required this.merchantName,
    required this.name,
    required this.originalPrice,
    required this.discountPrice,
    required this.quota,
    required this.pickupWindow,
  });

  bool get isAvailable => quota > 0;

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
