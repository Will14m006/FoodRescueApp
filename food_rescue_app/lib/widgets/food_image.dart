import 'package:flutter/material.dart';

import '../core/config/api_config.dart';
import '../core/theme/app_colors.dart';
import '../models/surplus_food_model.dart';

/// Foto makanan: unggahan merchant kalau ada, gambar bawaan kalau tidak.
///
/// Satu widget untuk seluruh aplikasi supaya katalog, detail, pemesanan,
/// dan dashboard merchant tidak punya aturan gambar yang berbeda. Tanpa ini
/// setiap layar akan menebak sendiri kapan memakai jaringan dan kapan aset.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.food,
    this.fit = BoxFit.cover,
    this.showEmojiFallback = true,
  });

  final SurplusFood food;
  final BoxFit fit;

  /// Emoji besar kalau tidak ada gambar sama sekali. Dimatikan di thumbnail
  /// kecil yang tidak butuh penanda tambahan.
  final bool showEmojiFallback;

  /// Aset lokal per kategori. Sengaja dibundel, bukan diunduh: demo tanpa
  /// internet tetap menampilkan gambar.
  static const _assets = {
    FoodCategory.bakery: 'assets/images/bakery.jpg',
    FoodCategory.main: 'assets/images/main.jpg',
    FoodCategory.snack: 'assets/images/snack.jpg',
    FoodCategory.drink: 'assets/images/drink.jpg',
  };

  String? get _networkUrl {
    final url = food.imageUrl;
    if (url == null) return null;
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    final network = _networkUrl;

    if (network != null) {
      return Image.network(
        network,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        // Foto hilang/rusak tidak boleh merusak seluruh card: jatuh ke
        // gambar bawaan, bukan kotak error.
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback(showSpinner: true);
        },
      );
    }

    return _fallback();
  }

  Widget _fallback({bool showSpinner = false}) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      child: showSpinner
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset(
              _assets[food.category] ?? _assets[FoodCategory.main]!,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => Text(
                showEmojiFallback ? food.emoji : '',
                style: const TextStyle(fontSize: 40),
              ),
            ),
    );
  }
}
