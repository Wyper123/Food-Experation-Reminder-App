import 'package:flutter/material.dart';
import 'package:food_expiration_reminder/core/widgets/skeleton_loader.dart';

/// Shimmer placeholder for the dashboard body: welcome card, metric row and
/// 4 "Use First" cards. Mirrors the loaded layout so nothing jumps on reveal.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key, this.urgentCount = 4});

  final int urgentCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 112, radius: 24),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: SkeletonBox(height: 108, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 108, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 108, radius: 18)),
            ],
          ),
          const SizedBox(height: 28),
          const Row(
            children: [
              SkeletonBox(width: 110, height: 18, radius: 6),
              Spacer(),
              SkeletonBox(width: 56, height: 14, radius: 6),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < urgentCount; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _UrgentCardSkeleton(),
            ),
        ],
      ),
    );
  }
}

class _UrgentCardSkeleton extends StatelessWidget {
  const _UrgentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SkeletonBox(width: 44, height: 44, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 14, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 11, radius: 6),
              ],
            ),
          ),
          SkeletonBox(width: 64, height: 26, radius: 10),
          SizedBox(width: 12),
          SkeletonBox(width: 6, height: 20, radius: 3),
        ],
      ),
    );
  }
}
