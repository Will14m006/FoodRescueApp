import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

/// P7 Advanced Feature #1: Autentikasi.
///
/// Form login terhubung ke API (`POST /auth/login`). Menampilkan:
///   - validasi input (email & password)
///   - state loading saat memanggil API
///   - state error (password salah / jaringan) + tombol coba lagi
///   - state sukses -> pindah ke dashboard
///
/// Akun demo: `emilys` / `emilyspass`
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'emilys');
  final _passwordController = TextEditingController(text: 'emilyspass');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email / username wajib diisi.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi.';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter.';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref.read(authProvider.notifier).login(
          username: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isLoading = authAsync.isLoading;

    ref.listen<AsyncValue<AuthUser?>>(authProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        }
      });
    });

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
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.xxxl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Masuk', style: AppTextStyles.headline),
                      const SizedBox(height: AppSpacing.xs + 2),
                      Text(
                        'Yuk mulai menyelamatkan makanan hari ini!',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      AppTextField(
                        label: 'Email / Username',
                        hint: 'nama@email.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Password',
                        hint: '••••••••',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        validator: _validatePassword,
                      ),

                      // === Error state ===
                      if (authAsync.hasError) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  authAsync.error.toString(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        text: isLoading ? 'Memproses...' : 'Masuk',
                        icon: Icons.login_rounded,
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _login,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Info akun demo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Akun demo: emilys / emilyspass',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
