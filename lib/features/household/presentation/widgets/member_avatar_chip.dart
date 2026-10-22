import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/constants/app_colors.dart';
import 'package:food_expiration_reminder/core/constants/app_text_styles.dart';
import 'package:food_expiration_reminder/data/models/household_model.dart';

/// Initials avatar coloured per member, with a small role icon overlay.
class MemberAvatarChip extends StatelessWidget {
  const MemberAvatarChip({super.key, required this.member, this.size = 48});

  final HouseholdMember member;
  final double size;

  static const _palette = [
    AppColors.emerald,
    AppColors.blue,
    AppColors.amber,
    AppColors.purple,
    AppColors.crimson,
  ];

  static IconData roleIcon(HouseholdRole r) => switch (r) {
        HouseholdRole.admin => Icons.shield_rounded,
        HouseholdRole.roommate => Icons.bed_rounded,
        HouseholdRole.familyMember => Icons.favorite_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _palette[member.colorIndex % _palette.length];
    final cs = Theme.of(context).colorScheme;
    final badge = size * 0.4;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              member.initials,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.onTintOf(context, color),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                // Deep shade in both themes so the white icon stays legible.
                color: AppColors.onTint(color, Brightness.light),
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              child: Icon(
                roleIcon(member.role),
                size: badge * 0.55,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
