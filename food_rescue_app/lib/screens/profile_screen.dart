import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // === Header ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg + 4,
                AppSpacing.xl,
                AppSpacing.xxxl + 4,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Profil',
                        style: AppTextStyles.headline.copyWith(color: AppColors.textOnPrimary),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.notifications_rounded,
                        color: AppColors.textOnPrimary,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.textOnPrimary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + 2),
                  Text(
                    'William',
                    style: AppTextStyles.headline.copyWith(color: AppColors.textOnPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    'Pembeli • Food Rescuer 🌱',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // === Statistik ===
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg + 4,
                AppSpacing.xl,
                AppSpacing.md + 2,
              ),
              child: Row(
                children: [
                  _StatCard(emoji: '🍽️', value: '12', label: 'Makanan Diselamatkan'),
                  const SizedBox(width: AppSpacing.md + 2),
                  _StatCard(emoji: '💵', value: 'Rp 180rb', label: 'Total Hemat'),
                ],
              ),
            ),

            // === Menu ===
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    _MenuTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Riwayat Pesanan',
                      subtitle: 'Lihat semua pesanan kamu',
                      onTap: () {},
                    ),
                    _MenuTile(
                      icon:Icons.location_on_rounded,
                      title: 'Alamat',
                      subtitle: 'Atur alamat pengambilan',
                      onTap: () {},
                    ),
                    _MenuTile(
                      icon: Icons.notifications_rounded,
                      title: 'Notifikasi',
                      subtitle: 'Atur preferensi notifikasi',
                      onTap: () {},
                    ),
                    _MenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Bantuan',
                      subtitle: 'Pusat bantuan & FAQ',
                      onTap: () {},
                    ),
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Tentang Aplikasi',
                      subtitle: 'Versi 1.0.0',
                      onTap: () {},
                    ),
                    const Spacer(),
                    Text(
                      'Food Rescue App • PBL Pemrograman Mobile',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(value, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: AppColors.primaryDark),
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
