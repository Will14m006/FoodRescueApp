import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Skeleton loading (shimmer) yang dipakai saat katalog sedang dimuat.
/// Memberi kesan aplikasi cepat & modern dibanding spinner biasa.
class FoodCardSkeleton extends StatelessWidget {
  const FoodCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBlock(
            height: 120,
            width: double.infinity,
            radius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBlock(height: 10, width: 90),
                SizedBox(height: 10),
                _SkeletonBlock(height: 14, width: double.infinity),
                SizedBox(height: 10),
                _SkeletonBlock(height: 10, width: 110),
                SizedBox(height: 14),
                _SkeletonBlock(height: 18, width: 100),
                SizedBox(height: AppSpacing.md),
                _SkeletonBlock(height: 34, width: double.infinity, radius: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;

  const _SkeletonBlock({
    required this.height,
    this.width,
    this.radius,
  });

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.35 + 0.35 * (_controller.value),
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: widget.radius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}
