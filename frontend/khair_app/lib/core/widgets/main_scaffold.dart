import 'package:khair_app/core/locale/l10n_extension.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../layout/app_breakpoints.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/events/presentation/bloc/events_bloc.dart';
import '../../features/notifications/presentation/widgets/notification_bell_button.dart';
import '../../tokens/tokens.dart';
import 'khair_brand.dart';

/// Navigation is derived from the authenticated session, never from a screen's
/// visibility alone. The router still enforces these same permissions.
class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
        builder: (context, auth) {
          final items = _itemsFor(context, auth);
          final desktop = AppBreakpoints.isDesktop(context);
          final path = GoRouterState.of(context).uri.path;
          return PopScope(
            canPop: path == '/',
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                context.go('/');
              }
            },
            child: Scaffold(
              appBar: desktop ? _DesktopNavigation(auth: auth) : null,
              body: child,
              extendBody: !desktop,
              bottomNavigationBar:
                  desktop ? null : _MobileNavigation(items: items),
            ),
          );
        },
      );

  List<_NavDestination> _itemsFor(BuildContext context, AuthState auth) {
    final l10n = context.l10n;
    final discover = _NavDestination(
        Icons.explore_outlined, Icons.explore, l10n.navDiscover, '/');
    final map =
        _NavDestination(Icons.map_outlined, Icons.map, l10n.navMap, '/map');
    final myEvents = _NavDestination(Icons.event_note_outlined,
        Icons.event_note, l10n.myEvents, '/my-events');
    final messages = _NavDestination(
        Icons.forum_outlined, Icons.forum, l10n.messages, '/messages');
    final profile = _NavDestination(Icons.person_outline_rounded, Icons.person,
        l10n.navProfile, '/profile');
    final dashboard = _NavDestination(Icons.dashboard_outlined,
        Icons.dashboard_rounded, l10n.organizerDashboard, '/organizer');
    final admin = _NavDestination(Icons.admin_panel_settings_outlined,
        Icons.admin_panel_settings, l10n.adminPanel, '/admin');
    if (!auth.isAuthenticated) return [discover, map];
    if (auth.isAdmin) return [discover, admin, profile];
    if (auth.isApprovedOrganizer) {
      return [discover, myEvents, messages, dashboard, profile];
    }
    return [discover, map, myEvents, messages, profile];
  }
}

class _DesktopNavigation extends StatelessWidget
    implements PreferredSizeWidget {
  final AuthState auth;
  const _DesktopNavigation({required this.auth});
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.sizeOf(context).width < 1280;
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: const Color(0xFF19181E),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 32,
      title: KhairBrand(
        size: 28,
        nameStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: Colors.white,
        ),
      ),
      actions: [
        _DesktopNavItem(
            icon: Icons.explore_outlined,
            label: context.l10n.navDiscover,
            color: AppColors.primary,
            selected: path == '/',
            compact: compact,
            onPressed: () => context.go('/')),
        _DesktopNavItem(
            icon: Icons.grid_view_rounded,
            label: context.l10n.categories,
            color: const Color(0xFF8B5CF6),
            selected: false,
            compact: compact,
            onPressed: () => context.go('/')),
        _DesktopNavItem(
            icon: Icons.videocam_outlined,
            label: context.l10n.online,
            color: const Color(0xFF3B82F6),
            selected: false,
            compact: compact,
            onPressed: () {
              final events = context.read<EventsBloc>();
              events.add(
                  UpdateFilter(events.state.filter.copyWith(onlineOnly: true)));
              context.go('/');
            }),
        _DesktopNavItem(
            icon: Icons.map_outlined,
            label: context.l10n.navMap,
            color: const Color(0xFF14B8A6),
            selected: _matches(path, '/map'),
            compact: compact,
            onPressed: () => context.go('/map')),
        if (auth.isAuthenticated)
          _DesktopNavItem(
            icon: Icons.bookmark_border_rounded,
            label: context.l10n.savedEvents,
            color: const Color(0xFFF5B942),
            selected: _matches(path, '/saved'),
            compact: compact,
            onPressed: () => context.go('/saved'),
          ),
        if (auth.isAuthenticated)
          _DesktopNavItem(
            icon: Icons.forum_outlined,
            label: context.l10n.messages,
            color: const Color(0xFF8B5CF6),
            selected: _matches(path, '/messages'),
            compact: compact,
            onPressed: () => context.go('/messages'),
          ),
        if (auth.isApprovedOrganizer)
          _DesktopNavItem(
            icon: Icons.dashboard_outlined,
            label: context.l10n.organizerDashboard,
            color: const Color(0xFFB49AF9),
            selected: _matches(path, '/organizer'),
            compact: compact,
            onPressed: () => context.go('/organizer'),
          ),
        const SizedBox(width: 4),
        if (auth.isAuthenticated)
          const IconTheme(
            data: IconThemeData(color: Color(0xFFFF7AA2)),
            child: _DesktopNotificationBell(),
          ),
        const SizedBox(width: 4),
        if (!auth.isAuthenticated)
          TextButton(
              onPressed: () => context.go('/login'),
              child: Text(context.l10n.signIn1,
                  style: const TextStyle(color: Colors.white)))
        else
          IconButton(
            tooltip: context.l10n.profileTooltip,
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle_outlined,
                color: Color(0xFFCFBEFF)),
          ),
        SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            if (!auth.isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context.l10n.signInOrRegisterToCreateAnEven)));
              context.go('/login?next=${Uri.encodeComponent('/create-event')}');
            } else {
              context.go(auth.isApprovedOrganizer
                  ? '/organizer/events/create'
                  : '/organizer/apply');
            }
          },
          style: FilledButton.styleFrom(
            minimumSize: Size(0, 44),
            padding: EdgeInsets.symmetric(horizontal: 18),
            shape: StadiumBorder(),
          ),
          child: Text(context.l10n.createEvent1),
        ),
        const SizedBox(width: 24),
      ],
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
      message: label,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? color : const Color(0xFFD9D3DE),
          minimumSize: const Size(0, 44),
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
          backgroundColor:
              selected ? color.withValues(alpha: .18) : Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: compact
            ? const SizedBox.shrink()
            : Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13)),
      ));
}

class _MobileNavigation extends StatelessWidget {
  final List<_NavDestination> items;
  const _MobileNavigation({required this.items});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final path = GoRouterState.of(context).uri.path;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, 10 + MediaQuery.paddingOf(context).bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: isDark ? Color(0xDD1A1F26) : Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                  color: Colors.black.withValues(alpha: isDark ? 0 : .06)),
            ),
            child: Row(children: [
              for (final item in items)
                Expanded(
                    child: _NavItem(
                        item: item, selected: _matches(path, item.route))),
            ]),
          ),
        ),
      ),
    );
  }
}

bool _matches(String path, String route) =>
    route == '/' ? path == '/' : path == route || path.startsWith('$route/');

class _NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavDestination(this.icon, this.activeIcon, this.label, this.route);
}

class _NavItem extends StatelessWidget {
  final _NavDestination item;
  final bool selected;
  const _NavItem({required this.item, required this.selected});
  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primary : Colors.black.withValues(alpha: .45);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(item.route),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(selected ? item.activeIcon : item.icon, color: color, size: 22),
        SizedBox(height: 3),
        Text(item.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color)),
      ]),
    );
  }
}

class _DesktopNotificationBell extends StatelessWidget {
  const _DesktopNotificationBell();

  @override
  Widget build(BuildContext context) => const NotificationBellButton();
}
