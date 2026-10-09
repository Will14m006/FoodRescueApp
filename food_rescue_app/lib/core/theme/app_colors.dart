import 'package:flutter/material.dart';

/// Palet warna Food Rescue App.
/// Hijau sebagai warna utama (kesan "selamat / segar"),
/// oranye sebagai aksen untuk diskon & urgensi (stok terbatas).
abstract class AppColors {
  // === Primary (hijau) ===
  static const primary = Color(0xFF0E9F6E);
  static const primaryDark = Color(0xFF0B7A55);
  static const primaryDarker = Color(0xFF08503A);
  static const primaryLight = Color(0xFFE4F4EC);
  static const primarySoft = Color(0xFFF0FAF5);

  // === Aksen (oranye) ===
  static const accent = Color(0xFFFF7A45);
  static const accentDark = Color(0xFFE85D2B);
  static const accentLight = Color(0xFFFFF0E8);

  // === Background & surface ===
  static const background = Color(0xFFF6F8F7);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFEFF3F1);

  // === Teks ===
  static const textPrimary = Color(0xFF17211D);
  static const textSecondary = Color(0xFF5D6B65);
  static const textHint = Color(0xFF93A19B);
  static const textOnPrimary = Colors.white;

  // === Status ===
  static const success = Color(0xFF30A46C);
  static const warning = Color(0xFFF5A524);
  static const warningLight = Color(0xFFFFF6E4);
  static const error = Color(0xFFE5484D);
  static const errorLight = Color(0xFFFFEBEC);

  // === Garis & border ===
  static const outline = Color(0xFFDDE4E1);
  static const outlineStrong = Color(0xFFC6D0CB);

  // === Gradient ===
  static const gradientStart = Color(0xFF0E9F6E);
  static const gradientEnd = Color(0xFF0B7A55);
}
