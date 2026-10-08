import 'package:flutter/material.dart';

/// Tombol utama reusable.
///
/// [isLoading] = true akan memunculkan indikator putar dan menonaktifkan tombol.
/// Inilah yang mencegah double-tap saat proses submit berjalan (syarat P4).
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: Colors.green.withValues(alpha: 0.6),
        ),
        // null = tombol non-aktif. Saat loading, onPressed di-set null
        // sehingga tap kedua dan seterusnya diabaikan oleh Flutter.
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}
