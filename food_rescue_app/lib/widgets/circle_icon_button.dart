import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// P8: tombol ikon bulat dengan target sentuh minimal 48x48, tooltip,
/// dan label semantik bawaan [IconButton] (aksesibilitas + feedback).
///
/// Menggantikan `GestureDetector` + `Container` yang targetnya cuma ~34px
/// dan tidak punya label untuk screen reader.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? background;
  final Color? foreground;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor:
            background ?? AppColors.textOnPrimary.withValues(alpha: 0.18),
        foregroundColor: foreground ?? AppColors.textOnPrimary,
        shape: const CircleBorder(),
      ),
    );
  }
}
