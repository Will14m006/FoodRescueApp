import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

/// Tombol utama reusable dengan gaya modern (pill, elevation halus).
///
/// [isLoading] = true akan memunculkan indikator putar dan menonaktifkan tombol.
/// Inilah yang mencegah double-tap saat proses submit berjalan (syarat P4).
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expanded;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? AppColors.textOnPrimary;

    return SizedBox(
      width: expanded ? double.infinity : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: onPressed == null || isLoading
              ? null
              : [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            disabledBackgroundColor: bg.withValues(alpha: 0.55),
            disabledForegroundColor: fg.withValues(alpha: 0.7),
          ),
          // null = tombol non-aktif. Saat loading, onPressed di-set null
          // sehingga tap kedua dan seterusnya diabaikan oleh Flutter.
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: fg,
                    strokeWidth: 2.4,
                  ),
                )
              : Row(
                  mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(text, style: AppTextStyles.button.copyWith(color: fg)),
                  ],
                ),
        ),
      ),
    );
  }
}
