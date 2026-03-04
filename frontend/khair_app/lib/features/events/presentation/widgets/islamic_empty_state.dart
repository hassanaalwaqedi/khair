import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../tokens/tokens.dart';

class IslamicEmptyState extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onRefresh;
  final IconData icon;

  const IslamicEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onRefresh,
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  State<IslamicEmptyState> createState() => _IslamicEmptyStateState();
}

class _IslamicEmptyStateState extends State<IslamicEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final dy = math.sin(t * math.pi * 2) * 8;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.14),
                            AppColors.secondary.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 114,
                      height: 114,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                        boxShadow: AppShadows.sm,
                      ),
                      child: Icon(
                        widget.icon,
                        size: 52,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(widget.buttonLabel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x3,
                      vertical: AppSpacing.x2,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
