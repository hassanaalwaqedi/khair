import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/presentation/widgets/notification_dropdown.dart';

/// Compact top app bar: Khair logo · location selector · notification + profile icons
class HomeAppBar extends StatelessWidget {
  final String? locationName;
  final VoidCallback? onLocationTap;
  final VoidCallback? onProfileTap;
  final String? profileImageUrl;

  const HomeAppBar({
    super.key,
    this.locationName,
    this.onLocationTap,
    this.onProfileTap,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
      color: KhairColors.darkSurface,
      child: Row(
        children: [
          // ── Logo ──
          const KhairBrandMark(size: 34, decorative: true),

          const SizedBox(width: 10),

          // ── Location selector ──
          if (locationName != null)
            GestureDetector(
              onTap: onLocationTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locationName!,
                    style: KhairTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
            ),

          const Spacer(),

          // ── Notification bell with badge ──
          _NotificationBell(),

          const SizedBox(width: 8),

          // ── Profile avatar ──
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: KhairColors.primaryDark,
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl!)
                  : null,
              child: profileImageUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (prev, curr) => prev.unreadCount != curr.unreadCount,
      builder: (context, state) {
        return GestureDetector(
          onTap: () => NotificationDropdown.show(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ),
                if (state.unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: KhairColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: KhairColors.darkSurface,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          state.unreadCount > 9
                              ? '9+'
                              : state.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
