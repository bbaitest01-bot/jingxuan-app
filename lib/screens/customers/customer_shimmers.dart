import 'package:flutter/material.dart';
import '../../widgets/animations.dart';

// Shimmer card widget for list loading states
class CustomerCardShimmer extends StatelessWidget {
  const CustomerCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar Shimmer
                const ShimmerLoader(width: 40, height: 40, borderRadius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // Name Shimmer
                      ShimmerLoader(width: 120, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      // Details Shimmer
                      ShimmerLoader(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Tags Shimmer
            Row(
              children: const [
                ShimmerLoader(width: 50, height: 18, borderRadius: 4),
                SizedBox(width: 8),
                ShimmerLoader(width: 60, height: 18, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Shimmer list card widget for list loading states
class CustomerListShimmer extends StatelessWidget {
  const CustomerListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Avatar
            const ShimmerLoader(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: 16),
            // Name
            const ShimmerLoader(width: 100, height: 16, borderRadius: 4),
            const SizedBox(width: 24),
            // Contact info (Wide screen simulation or general spacing)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  ShimmerLoader(width: 120, height: 10, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerLoader(width: 140, height: 10, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Tags shimmer
            Expanded(
              flex: 2,
              child: Row(
                children: const [
                  ShimmerLoader(width: 60, height: 18, borderRadius: 4),
                  SizedBox(width: 8),
                  ShimmerLoader(width: 50, height: 18, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Actions
            const ShimmerLoader(width: 80, height: 24, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}
