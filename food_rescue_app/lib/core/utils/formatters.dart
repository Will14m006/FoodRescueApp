/// P9: formatter terpusat — dulu format Rupiah diduplikasi di 3 tempat
/// dengan hasil berbeda ("Rp 15000" vs "Rp 15.000").
abstract class Formatters {
  /// 15000 -> "Rp 15.000"
  static String rupiah(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }

    return 'Rp ${negative ? '-' : ''}$buffer';
  }

  /// DateTime -> "5/11/2026 • 14:30 WIB"
  static String dateTime(DateTime value) {
    final d = value.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} • $hh:$mm WIB';
  }
}
