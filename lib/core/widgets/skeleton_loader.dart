import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Wraps skeleton shapes in a single shimmer sweep.
/// Child shapes must be built from opaque (white) [SkeletonBox]/[SkeletonCircle].
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: baseColor ??
          (dark ? AppColors.shimmerBaseDark : AppColors.shimmerBase),
      highlightColor: highlightColor ??
          (dark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlight),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox(
      {super.key, this.width, this.height = 16, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}
