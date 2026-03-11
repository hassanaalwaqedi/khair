import 'package:flutter/material.dart';
import '../../../../core/theme/khair_theme.dart';

// ─────────────────────────────────────────────────────────
// DashboardCard – Reusable quick-action card with hover
// ─────────────────────────────────────────────────────────

class DashboardCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool disabled;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor,
    this.disabled = false,
  });

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.iconColor ?? KhairColors.primary;
    final opacity = widget.disabled ? 0.45 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: KhairAnimations.fast,
          curve: KhairAnimations.defaultCurve,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? KhairColors.darkCard : KhairColors.surface,
            borderRadius: KhairRadius.large,
            border: Border.all(
              color: _isHovered && !widget.disabled
                  ? color.withAlpha(80)
                  : (isDark ? KhairColors.darkBorder : KhairColors.border),
            ),
            boxShadow: _isHovered && !widget.disabled
                ? KhairShadows.hover
                : KhairShadows.sm,
          ),
          transform: _isHovered && !widget.disabled
              ? Matrix4.translationValues(0.0, -2.0, 0.0)
              : Matrix4.identity(),
          child: Opacity(
            opacity: opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: KhairRadius.medium,
                  ),
                  child: Icon(widget.icon, color: color, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: KhairTypography.labelLarge.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: KhairTypography.bodySmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextTertiary
                        : KhairColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// AnimatedStatCard – Counter animation + icon
// ─────────────────────────────────────────────────────────

class AnimatedStatCard extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const AnimatedStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: KhairRadius.medium,
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(25),
                  borderRadius: KhairRadius.small,
                ),
                child: Icon(widget.icon, size: 18, color: widget.color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Text(
                _animation.value.toInt().toString(),
                style: KhairTypography.h2.copyWith(
                  color: isDark
                      ? KhairColors.darkTextPrimary
                      : KhairColors.textPrimary,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            style: KhairTypography.bodySmall.copyWith(
              color: isDark
                  ? KhairColors.darkTextTertiary
                  : KhairColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ShimmerLoading – Placeholder shimmer effect
// ─────────────────────────────────────────────────────────

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? KhairColors.darkSurfaceVariant : KhairColors.neutral200;
    final highlightColor =
        isDark ? KhairColors.darkBorder : KhairColors.neutral100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Convenience widget for building a shimmer skeleton layout
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header shimmer
          const ShimmerLoading(height: 120, borderRadius: 20),
          const SizedBox(height: 24),
          // Quick actions shimmer
          const ShimmerLoading(height: 20, width: 120, borderRadius: 6),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: ShimmerLoading(height: 120)),
              const SizedBox(width: 16),
              const Expanded(child: ShimmerLoading(height: 120)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: ShimmerLoading(height: 120)),
              const SizedBox(width: 16),
              const Expanded(child: ShimmerLoading(height: 120)),
            ],
          ),
          const SizedBox(height: 24),
          // Stats shimmer
          const ShimmerLoading(height: 20, width: 100, borderRadius: 6),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              4,
              (_) => const Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: ShimmerLoading(height: 100),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Events shimmer
          const ShimmerLoading(height: 20, width: 140, borderRadius: 6),
          const SizedBox(height: 16),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerLoading(height: 72),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// RBACBanner – Warning banner for pending/rejected organizers
// ─────────────────────────────────────────────────────────

class RBACBanner extends StatelessWidget {
  final String status;
  final String? rejectionReason;

  const RBACBanner({
    super.key,
    required this.status,
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';

    if (!isPending && !isRejected) return const SizedBox.shrink();

    final color = isPending ? KhairColors.warning : KhairColors.error;
    final bgColor = isPending ? KhairColors.warningLight : KhairColors.errorLight;
    final icon = isPending ? Icons.hourglass_top_rounded : Icons.block_rounded;
    final title = isPending
        ? 'Account Pending Approval'
        : 'Account Rejected';
    final message = isPending
        ? 'Your organizer account is awaiting admin approval. Some features are restricted until approved.'
        : rejectionReason ?? 'Your application was rejected. Please contact support for details.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: KhairRadius.medium,
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KhairTypography.labelLarge.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: KhairTypography.bodySmall.copyWith(
                    color: color.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
