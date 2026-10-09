import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../routes/app_routes.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // === Hero ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xxxl + 8,
                  AppSpacing.xxl,
                  AppSpacing.xxxl + 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.textOnPrimary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Food Rescue',
                      style: AppTextStyles.display.copyWith(
                        color: AppColors.textOnPrimary,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      'Selamatkan makanan surplus, nikmati harga diskon',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // === Form ===
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xxxl + 8,
                  AppSpacing.xxl,
                  AppSpacing.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Masuk', style: AppTextStyles.headline),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      'Yuk mulai menyelamatkan makanan hari ini!',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const AppTextField(
                      label: 'Email',
                      hint: 'nama@email.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppTextField(
                      label: 'Password',
                      hint: '••••••••',
                      isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Lupa password?'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      text: 'Masuk',
                      icon: Icons.login_rounded,
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Text('atau', style: AppTextStyles.caption),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Belum punya akun? ', style: AppTextStyles.body),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            'Daftar Sekarang',
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
