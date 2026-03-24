import 'package:flutter/material.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../domain/entities/sheikh_profile.dart';
import '../pages/sheikh_profile_page.dart';

/// "Learn from Scholars" — marketplace-style horizontal cards.
class SheikhDirectorySection extends StatelessWidget {
  final List<SheikhProfile> sheikhs;
  const SheikhDirectorySection({super.key, required this.sheikhs});

  @override
  Widget build(BuildContext context) {
    if (sheikhs.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Icon(Icons.school_rounded, color: KhairColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(context.l10n.sheikhLearnFromScholars, style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: tp, letterSpacing: -0.3)),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: sheikhs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _ScholarCard(
              sheikh: sheikhs[i], cardBg: cardBg, bdr: bdr, tp: tp, ts: ts, isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScholarCard extends StatelessWidget {
  final SheikhProfile sheikh;
  final Color cardBg, bdr, tp, ts;
  final bool isDark;

  const _ScholarCard({
    required this.sheikh, required this.cardBg, required this.bdr,
    required this.tp, required this.ts, required this.isDark,
  });

  static const _baseUrl = 'https://khair.it.com';

  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$_baseUrl$url';
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = _resolveUrl(sheikh.avatarUrl);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SheikhProfilePage(sheikh: sheikh))),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bdr),
        ),
        child: Column(
          children: [
            // Avatar + "New" badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: KhairColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: KhairColors.primary.withValues(alpha: 0.2), width: 2),
                    image: imgUrl.isNotEmpty ? DecorationImage(
                      image: NetworkImage(imgUrl), fit: BoxFit.cover,
                    ) : null,
                  ),
                  child: imgUrl.isEmpty ? Center(child: Text(
                    sheikh.name.isNotEmpty ? sheikh.name[0].toUpperCase() : 'S',
                    style: TextStyle(color: KhairColors.primary, fontSize: 22, fontWeight: FontWeight.w700),
                  )) : null,
                ),
                if (sheikh.isNew)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(context.l10n.sheikhNew,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Name
            Text(sheikh.name, textAlign: TextAlign.center, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tp)),
            const SizedBox(height: 3),
            // Specialty
            Text(
              sheikh.specialization ?? 'Islamic Studies',
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: ts),
            ),
            const SizedBox(height: 4),
            // Rating
            if (sheikh.totalReviews > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFC107)),
                  const SizedBox(width: 2),
                  Text(
                    sheikh.averageRating.toStringAsFixed(1),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tp),
                  ),
                  const SizedBox(width: 2),
                  Text('(${sheikh.totalReviews})',
                      style: TextStyle(fontSize: 10, color: ts)),
                ],
              ),
            const Spacer(),
            // CTA
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SheikhProfilePage(sheikh: sheikh))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KhairColors.primary,
                  side: BorderSide(color: KhairColors.primary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: Text(context.l10n.sheikhViewProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
