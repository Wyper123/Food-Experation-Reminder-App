import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';

enum CustomButtonVariant { primary, secondary, danger, text }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CustomButtonVariant variant;

  /// Shows a shimmer pill instead of the button (no spinners).
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SkeletonLoader(
        child: SkeletonBox(
          width: expanded ? double.infinity : 140,
          height: 52,
          radius: 16,
        ),
      );
    }

    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final minSize = Size(expanded ? double.infinity : 0, 52);
    final textStyle = AppTextStyles.subtitle;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    switch (variant) {
      case CustomButtonVariant.primary:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: minSize,
            shape: shape,
            textStyle: textStyle,
          ),
          child: child,
        );
      case CustomButtonVariant.danger:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: minSize,
            shape: shape,
            textStyle: textStyle,
            backgroundColor: AppColors.crimson,
            foregroundColor: Colors.white,
          ),
          child: child,
        );
      case CustomButtonVariant.secondary:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: minSize,
            shape: shape,
            textStyle: textStyle,
          ),
          child: child,
        );
      case CustomButtonVariant.text:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size(expanded ? double.infinity : 0, 44),
            shape: shape,
            textStyle: textStyle,
          ),
          child: child,
        );
    }
  }
}
