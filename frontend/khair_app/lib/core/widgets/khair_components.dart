import 'package:flutter/material.dart';
import '../theme/khair_theme.dart';
import '../utils/emoji_mapper.dart';

/// Primary CTA Button with press-scale micro-interaction
class KhairButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final bool fullWidth;

  const KhairButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  State<KhairButton> createState() => _KhairButtonState();
}

class _KhairButtonState extends State<KhairButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: KhairAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isOutlined ? KhairColors.primary : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(widget.label),
      ],
    );

    final button = widget.isOutlined
        ? SizedBox(
            width: widget.fullWidth ? double.infinity : null,
            child: OutlinedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              child: child,
            ),
          )
        : SizedBox(
            width: widget.fullWidth ? double.infinity : null,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              child: child,
            ),
          );

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: button,
      ),
    );
  }
}

/// Card with hover effect
class KhairCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool hoverable;

  const KhairCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.hoverable = true,
  });

  @override
  State<KhairCard> createState() => _KhairCardState();
}

class _KhairCardState extends State<KhairCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.hoverable ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.hoverable ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: KhairColors.surface,
          borderRadius: KhairRadius.medium,
          border: Border.all(
            color: _isHovered ? KhairColors.primary.withAlpha(50) : KhairColors.border,
          ),
          boxShadow: _isHovered ? KhairShadows.md : KhairShadows.sm,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: KhairRadius.medium,
            child: Padding(
              padding: widget.padding ?? KhairSpacing.cardPadding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Verified Badge
class VerifiedBadge extends StatelessWidget {
  final bool large;

  const VerifiedBadge({super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 6,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: KhairColors.verifiedLight,
        borderRadius: BorderRadius.circular(large ? 8 : 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: large ? 16 : 12,
            color: KhairColors.verified,
          ),
          SizedBox(width: large ? 6 : 4),
          Text(
            'Verified',
            style: (large ? KhairTypography.labelMedium : KhairTypography.labelSmall)
                .copyWith(color: KhairColors.verified),
          ),
        ],
      ),
    );
  }
}

/// Status Badge with emoji prefix
class StatusBadge extends StatelessWidget {
  final String status;
  final Color? color;

  const StatusBadge({
    super.key,
    required this.status,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = color ?? _getStatusColor(status);
    final bgColor = statusColor.withAlpha(26);
    final emoji = _getStatusEmoji(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$emoji ${status[0].toUpperCase()}${status.substring(1)}',
        style: KhairTypography.labelSmall.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
      case 'published':
        return successEmoji;
      case 'pending':
      case 'review':
        return pendingEmoji;
      case 'rejected':
      case 'suspended':
        return rejectedEmoji;
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
      case 'published':
        return KhairColors.success;
      case 'pending':
      case 'review':
        return KhairColors.warning;
      case 'rejected':
      case 'suspended':
        return KhairColors.error;
      default:
        return KhairColors.textTertiary;
    }
  }
}

/// Section Header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KhairTypography.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: KhairTypography.bodyMedium),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Empty State
class KhairEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KhairEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KhairColors.surfaceVariant,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                icon,
                size: 36,
                color: KhairColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: KhairTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: KhairTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              KhairButton(
                label: actionLabel!,
                onPressed: onAction,
                isOutlined: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading State
class KhairLoadingState extends StatelessWidget {
  final String? message;

  const KhairLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: KhairColors.primary,
            strokeWidth: 3,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: KhairTypography.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Error State
class KhairErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const KhairErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KhairColors.errorLight,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 36,
                color: KhairColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: KhairTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: KhairTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              KhairButton(
                label: 'Try Again',
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filter Chip
class KhairFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const KhairFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? KhairColors.primary : KhairColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? KhairColors.primary : KhairColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : KhairColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: KhairTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : KhairColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
