import 'package:flutter/material.dart';
import '../theme/khair_theme.dart';

/// Shimmer loading effect for skeleton screens
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: isDark
                  ? [
                      KhairColors.darkSurfaceVariant,
                      KhairColors.darkCard,
                      KhairColors.darkSurfaceVariant,
                    ]
                  : [
                      KhairColors.neutral200,
                      KhairColors.neutral100,
                      KhairColors.neutral200,
                    ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton box for loading placeholders
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkSurfaceVariant : KhairColors.neutral200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Event card skeleton for loading state
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: BorderRadius.circular(KhairRadius.lg),
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
        boxShadow: KhairShadows.sm,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          SkeletonBox(height: 150, borderRadius: 12),
          SizedBox(height: 12),
          // Title
          SkeletonBox(width: 200, height: 20),
          SizedBox(height: 8),
          // Subtitle
          SkeletonBox(width: 150, height: 14),
          SizedBox(height: 12),
          // Date and location
          Row(
            children: [
              SkeletonBox(width: 100, height: 14),
              SizedBox(width: 16),
              SkeletonBox(width: 120, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

/// Events list skeleton
class EventsListSkeleton extends StatelessWidget {
  final int itemCount;

  const EventsListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) => const EventCardSkeleton(),
      ),
    );
  }
}

/// Organizer card skeleton
class OrganizerCardSkeleton extends StatelessWidget {
  const OrganizerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: BorderRadius.circular(KhairRadius.lg),
      ),
      child: const Row(
        children: [
          // Avatar
          SkeletonBox(width: 48, height: 48, borderRadius: 24),
          SizedBox(width: 12),
          // Name and email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 16),
                SizedBox(height: 6),
                SkeletonBox(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
