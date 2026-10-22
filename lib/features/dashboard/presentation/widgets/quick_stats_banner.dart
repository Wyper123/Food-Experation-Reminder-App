import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';

/// Metrics row: Expiring Soon (amber), Expired (crimson), Total Stored (emerald).
class QuickStatsBanner extends StatelessWidget {
  const QuickStatsBanner({
    super.key,
    required this.expiringSoon,
    required this.expired,
    required this.totalStored,
    this.onExpiringSoonTap,
    this.onExpiredTap,
    this.onTotalTap,
  });

  final int expiringSoon;
  final int expired;
  final int totalStored;
  final VoidCallback? onExpiringSoonTap;
  final VoidCallback? onExpiredTap;
  final VoidCallback? onTotalTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Expiring soon',
            value: expiringSoon,
            icon: Icons.schedule_rounded,
            color: AppColors.amber,
            onTap: onExpiringSoonTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Expired',
            value: expired,
            icon: Icons.error_outline_rounded,
            color: AppColors.crimson,
            onTap: onExpiredTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Total stored',
            value: totalStored,
            icon: Icons.inventory_2_outlined,
            color: AppColors.emerald,
            onTap: onTotalTap,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.onTint(color, Theme.of(context).brightness);
    return Material(
      color: color.withValues(alpha: dark ? 0.18 : 0.11),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 14),
              Text(
                '$value',
                style: AppTextStyles.display.copyWith(color: fg, fontSize: 26),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
