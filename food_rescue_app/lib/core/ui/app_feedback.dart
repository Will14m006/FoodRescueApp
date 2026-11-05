import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// P8: snackbar umpan balik aksi — satu tempat untuk pesan sukses/gagal,
/// supaya setiap aksi di UI selalu memberi respons (tidak "diam").
abstract class AppFeedback {
  static void success(BuildContext context, String message) {
    _show(context, message, AppColors.primaryDarker, Icons.check_circle_rounded);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppColors.error, Icons.error_outline_rounded);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppColors.textPrimary, Icons.info_outline_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color background,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textOnPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.base.copyWith(
                    color: AppColors.textOnPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
