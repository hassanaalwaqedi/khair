import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';

/// Community impact section at the bottom: real stats + CTA
class CommunityImpactFooter extends StatelessWidget {
  final int totalAttendees;
  final int totalEvents;

  const CommunityImpactFooter({
    super.key,
    required this.totalAttendees,
    required this.totalEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 100), // 100 for bottom nav
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: KhairColors.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'COMMUNITY IMPACT',
                style: KhairTypography.labelMedium.copyWith(
                  color: KhairColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stat line
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontFamily: KhairTypography.fontFamily,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: _formatCount(totalAttendees),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const TextSpan(
                    text: ' People gathering today across '),
                TextSpan(
                  text: '$totalEvents events.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // CTA
          Text(
            'JOIN THE MOVEMENT',
            style: TextStyle(
              color: KhairColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
