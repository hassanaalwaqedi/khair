import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../domain/entities/owner_post.dart';

/// "Khair Recommends" section for the home page.
/// Shows only active owner posts. Hides itself if no posts exist.
class KhairRecommendsSection extends StatelessWidget {
  final List<OwnerPost> posts;
  const KhairRecommendsSection({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(
          title: 'Khair Recommends',
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: posts.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 14),
            itemBuilder: (context, i) {
              return AppFadeSlideIn(
                delayMs: i * 100,
                slideOffset: const Offset(20, 0),
                child: _RecommendCard(post: posts[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendCard extends StatelessWidget {
  final OwnerPost post;
  const _RecommendCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y').format(post.publishedAt);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha(0.05),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.whiteAlpha(0.07)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image or gradient header
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
              gradient: post.imageUrl == null
                  ? AppGradients.emeraldGlow
                  : null,
              image: post.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(post.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.goldAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 10,
                            color: AppColors.emeraldDark),
                        SizedBox(width: 3),
                        Text(
                          'Verified by Khair',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: AppTypography.cardTitle.copyWith(
                        fontSize: 14, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.shortDescription,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.whiteAlpha(0.5),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(dateStr, style: AppTypography.caption),
                      const Spacer(),
                      if (post.externalLink != null)
                        GestureDetector(
                          onTap: () => debugPrint(
                              'Open: ${post.externalLink}'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.goldAccent
                                  .withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Visit',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
