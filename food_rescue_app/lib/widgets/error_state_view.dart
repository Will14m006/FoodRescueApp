import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

/// Error state reusable dengan tombol Retry.
///
/// Pesan error dari Exception masih mentah (contoh "Exception: ...") sehingga
/// perlu dibersihkan dulu agar ramah dibaca pengguna.
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateView({super.key, required this.message, required this.onRetry});

  String get _cleanMessage => message.replaceFirst('Exception: ', '').trim();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('📡', style: TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Yah, ada yang salah', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _cleanMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Coba Lagi', style: AppTextStyles.button),
            ),
          ],
        ),
      ),
    );
  }
}
