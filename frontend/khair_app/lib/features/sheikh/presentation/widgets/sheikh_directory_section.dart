import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../domain/entities/sheikh_profile.dart';
import '../pages/sheikh_profile_page.dart';

/// "Find a Sheikh" directory section for the Discover page.
/// Displays sheikh cards horizontally. Hides itself if no sheikhs exist.
class SheikhDirectorySection extends StatelessWidget {
  final List<SheikhProfile> sheikhs;
  const SheikhDirectorySection({super.key, required this.sheikhs});

  @override
  Widget build(BuildContext context) {
    if (sheikhs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(
          title: 'Find a Sheikh',
          icon: Icons.school_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: sheikhs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              return AppFadeSlideIn(
                delayMs: i * 100,
                slideOffset: const Offset(20, 0),
                child: _SheikhCard(sheikh: sheikhs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SheikhCard extends StatelessWidget {
  final SheikhProfile sheikh;
  const _SheikhCard({required this.sheikh});

  static const _baseUrl =
      'https://khair.it.com';

  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$_baseUrl$url';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolveUrl(sheikh.avatarUrl);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SheikhProfilePage(sheikh: sheikh),
          ),
        );
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: AppColors.whiteAlpha(0.05),
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.whiteAlpha(0.07)),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            const SizedBox(height: 18),
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B5F50), Color(0xFF2D8E75)],
                    ),
                    border: Border.all(
                      color: AppColors.goldAccent.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            width: 72,
                            height: 72,
                            errorBuilder: (_, __, ___) => _buildInitials(),
                          ),
                        )
                      : _buildInitials(),
                ),
                // Verified badge
                if (sheikh.isVerified)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.goldAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                sheikh.name,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            // Specialization
            if (sheikh.specialization != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  sheikh.specialization!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.goldAccent.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            // Bottom info row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sheikh.city != null) ...[
                    Icon(Icons.location_on_outlined,
                        size: 11, color: AppColors.whiteAlpha(0.4)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        sheikh.city!,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (sheikh.city != null && sheikh.yearsOfExperience != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('•',
                          style: TextStyle(
                              color: AppColors.whiteAlpha(0.3), fontSize: 8)),
                    ),
                  if (sheikh.yearsOfExperience != null)
                    Text(
                      '${sheikh.yearsOfExperience}y exp',
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        sheikh.name[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
