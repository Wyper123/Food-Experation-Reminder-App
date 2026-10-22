import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';

/// Shimmer placeholder mirroring the layout of FoodCard.
/// Contains no loader of its own; wrap in [SkeletonLoader] (see [FoodListSkeleton]).
class FoodCardSkeleton extends StatelessWidget {
  const FoodCardSkeleton({super.key});

  Widget _line(double factor, double height) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: SkeletonBox(height: height, radius: 6),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SkeletonBox(width: 48, height: 48, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(0.6, 14),
                const SizedBox(height: 8),
                _line(0.45, 11),
                const SizedBox(height: 8),
                _line(0.35, 11),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 76, height: 24, radius: 12),
              SizedBox(height: 10),
              SkeletonBox(width: 48, height: 11, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class FoodListSkeleton extends StatelessWidget {
  const FoodListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        children: List.generate(
          itemCount,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: FoodCardSkeleton(),
          ),
        ),
      ),
    );
  }
}
