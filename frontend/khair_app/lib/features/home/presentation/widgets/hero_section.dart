import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../events/presentation/pages/event_search_page.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/presentation/widgets/notification_dropdown.dart';
import '../../../../core/theme/theme_bloc.dart';
import '../../../../core/widgets/language_switcher.dart';

/// Clean, minimal header with greeting, search bar, and action buttons.
class HeroSection extends StatelessWidget {
  final String userName;
  const HeroSection({super.key, this.userName = ''});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KhairColors.darkSurface : KhairColors.surface;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final tt = isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;
    final searchBg = isDark ? KhairColors.darkSurfaceVariant : KhairColors.surfaceVariant;

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP ROW: Brand + Actions ──
          Row(
            children: [
              // Khair logo
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: KhairColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mosque, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Khair', style: TextStyle(
                fontSize: 22, color: tp, fontWeight: FontWeight.w800, letterSpacing: 0.3,
              )),
              const Spacer(),
              // Language switcher
              const LanguageSwitcher(showLabel: false, lightStyle: false),
              const SizedBox(width: 6),
              // Theme toggle
              BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, _) {
                  return _actionBtn(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? KhairColors.secondary : tt,
                    bgColor: searchBg,
                    border: bdr,
                    onTap: () => context.read<ThemeBloc>().add(const ToggleTheme()),
                  );
                },
              ),
              const SizedBox(width: 6),
              // Notifications
              BlocConsumer<NotificationBloc, NotificationState>(
                listenWhen: (prev, curr) => curr.unreadCount > prev.unreadCount,
                listener: (context, state) {
                  SystemSound.play(SystemSoundType.alert);
                  HapticFeedback.mediumImpact();
                },
                buildWhen: (prev, curr) => prev.unreadCount != curr.unreadCount,
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () => NotificationDropdown.show(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: searchBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bdr),
                      ),
                      child: Center(
                        child: state.unreadCount > 0
                            ? Badge(
                                label: Text(
                                  state.unreadCount > 9 ? '9+' : '${state.unreadCount}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                                child: Icon(Icons.notifications_outlined, color: tp, size: 22),
                              )
                            : Icon(Icons.notifications_outlined, color: tt, size: 22),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── GREETING ──
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.greeting} 👋',
                  style: TextStyle(fontSize: 14, color: ts, fontWeight: FontWeight.w500),
                ),
                if (userName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(userName, style: TextStyle(
                    fontSize: 24, color: tp, fontWeight: FontWeight.w700, letterSpacing: -0.3,
                  )),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── SEARCH BAR ──
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventSearchPage()),
              );
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bdr),
              ),
              child: Row(children: [
                Icon(Icons.search_rounded, color: tt, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  context.l10n.searchEventsHint,
                  style: TextStyle(color: tt, fontSize: 14, fontWeight: FontWeight.w400),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KhairColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded, color: KhairColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(context.l10n.allCities, style: TextStyle(
                        color: KhairColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required Color color,
      required Color bgColor, required Color border, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Center(child: Icon(icon, color: color, size: 20)),
      ),
    );
  }
}
