import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';

/// Trust-level banner: "Your Trust Level: SILVER | Keep attending"
class TrustLevelBanner extends StatelessWidget {
  final String level;
  final String message;

  const TrustLevelBanner({
    super.key,
    required this.level,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Shield icon
          Icon(
            Icons.verified_user_outlined,
            color: KhairColors.secondary,
            size: 20,
          ),
          const SizedBox(width: 10),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: KhairTypography.fontFamily,
                    ),
                    children: [
                      const TextSpan(text: 'Your Trust Level: '),
                      TextSpan(
                        text: level.toUpperCase(),
                        style: TextStyle(
                          color: KhairColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' | $message'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'to unlock organizer mode',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // VIEW DASHBOARD link
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Text(
              'VIEW DASHBOARD',
              style: TextStyle(
                color: KhairColors.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
