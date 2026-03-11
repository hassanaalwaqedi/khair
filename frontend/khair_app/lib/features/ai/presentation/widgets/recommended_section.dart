import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';
import '../bloc/ai_bloc.dart';

/// "🎯 Recommended for You" horizontal section
class RecommendedSection extends StatelessWidget {
  const RecommendedSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiBloc, AiState>(
      buildWhen: (p, c) =>
          p.recommendationsStatus != c.recommendationsStatus ||
          p.recommendations != c.recommendations,
      builder: (context, state) {
        // Don't show if loading, error, or empty
        if (state.recommendationsStatus != AiStatus.loaded ||
            state.recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                KhairSpacing.md, KhairSpacing.sm, KhairSpacing.md, KhairSpacing.xs,
              ),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Recommended for You',
                    style: KhairTypography.h3.copyWith(
                      color: isDark
                          ? KhairColors.darkTextPrimary
                          : KhairColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // AI badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [KhairColors.accent, KhairColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(KhairRadius.sm),
                    ),
                    child: const Text(
                      '✨ AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: KhairSpacing.md),
                itemCount: state.recommendations.length,
                itemBuilder: (context, index) {
                  final rec = state.recommendations[index];
                  return _RecommendationChip(
                    eventId: rec.eventId,
                    score: rec.relevanceScore,
                    reasoning: rec.reasoning,
                    onTap: () {
                      // Track the click interaction
                      context.read<AiBloc>().add(TrackInteraction(
                            eventId: rec.eventId,
                            interactionType: 'click',
                          ));
                      context.go('/events/${rec.eventId}');
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  final String eventId;
  final double score;
  final String reasoning;
  final VoidCallback onTap;

  const _RecommendationChip({
    required this.eventId,
    required this.score,
    required this.reasoning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matchPercent = (score * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsetsDirectional.only(end: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? KhairColors.darkCard : KhairColors.surface,
          borderRadius: BorderRadius.circular(KhairRadius.md),
          border: Border.all(
            color: KhairColors.primary.withAlpha(40),
          ),
          boxShadow: KhairShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Match score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getScoreColor(score).withAlpha(25),
                    borderRadius: BorderRadius.circular(KhairRadius.xs),
                  ),
                  child: Text(
                    '$matchPercent% match',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              reasoning.isNotEmpty ? reasoning : 'Tailored for your interests',
              style: KhairTypography.bodySmall.copyWith(
                color: isDark
                    ? KhairColors.darkTextSecondary
                    : KhairColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  'View event →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KhairColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return KhairColors.success;
    if (score >= 0.6) return KhairColors.primary;
    if (score >= 0.4) return KhairColors.secondary;
    return KhairColors.textTertiary;
  }
}
