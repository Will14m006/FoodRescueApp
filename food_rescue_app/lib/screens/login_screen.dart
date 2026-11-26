import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/validation/validators.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_body.dart';

/// Masuk atau daftar akun ke backend sendiri.
///
/// Satu layar dengan dua mode: form-nya sama, hanya jumlah field & aksi yang
/// berbeda. Memisahkan jadi dua layar berarti menduplikasi seluruh hero,
/// padding, dan penanganan error.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(text: 'buyer@foodrescue.id');
  final _passwordController = TextEditingController(text: 'DemoFood123');

  bool _isRegister = false;
  UserRole _role = UserRole.buyer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      // Daftar sebagai admin tidak mungkin: backend menolaknya dengan 403.
      if (!_isRegister) _role = UserRole.buyer;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(authProvider.notifier);
    if (_isRegister) {
      await notifier.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role,
      );
    } else {
      await notifier.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isLoading = authAsync.isLoading;

    ref.listen<AsyncValue<AuthUser?>>(authProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ResponsiveBody(
            maxWidth: 480,
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
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(32)),
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
                        Text(
                          _isRegister ? 'Daftar Akun' : 'Masuk',
                          style: AppTextStyles.headline,
                        ),
                        const SizedBox(height: AppSpacing.xs + 2),
                        Text(
                          _isRegister
                              ? 'Pilih peran: pembeli atau merchant.'
                              : 'Yuk mulai menyelamatkan makanan hari ini!',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        if (_isRegister) ...[
                          AppTextField(
                            label: 'Nama',
                            hint: 'Nama lengkap',
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            controller: _nameController,
                            validator: (v) =>
                                Validators.minLength(v, label: 'Nama', min: 2),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        AppTextField(
                          label: 'Email',
                          hint: 'nama@email.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          controller: _emailController,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Password',
                          hint: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          controller: _passwordController,
                          validator: (v) =>
                              Validators.minLength(v, label: 'Password', min: 8),
                        ),

                        if (_isRegister) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Daftar sebagai',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              for (final role in [UserRole.buyer, UserRole.merchant])
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.sm,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(role.label),
                                    selected: _role == role,
                                    showCheckmark: false,
                                    onSelected: (_) =>
                                        setState(() => _role = role),
                                  ),
                                ),
                            ],
                          ),
                        ],

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
                          text: isLoading
                              ? 'Memproses...'
                              : (_isRegister ? 'Daftar' : 'Masuk'),
                          icon: _isRegister
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _submit,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: isLoading ? null : _toggleMode,
                          child: Text(
                            _isRegister
                                ? 'Sudah punya akun? Masuk'
                                : 'Belum punya akun? Daftar',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Info akun demo + alamat server yang dituju.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Akun demo (setelah seed):',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'buyer@foodrescue.id / DemoFood123\n'
                                'toko@foodrescue.id / DemoFood123',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Server: ${ref.watch(apiBaseUrlProvider)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textHint,
                                  fontSize: 11,
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
      ),
    );
  }
}
