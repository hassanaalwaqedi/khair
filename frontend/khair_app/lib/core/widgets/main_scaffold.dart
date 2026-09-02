import 'package:khair_app/core/locale/l10n_extension.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../layout/app_breakpoints.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
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
    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 32,
      title: KhairBrand(
        size: 28,
        nameStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
      ),
      actions: [
        _DesktopNavLink(
            label: context.l10n.navDiscover,
            selected: path == '/',
            onPressed: () => context.go('/')),
        _DesktopNavLink(
            label: context.l10n.navMap,
            selected: _matches(path, '/map'),
            onPressed: () => context.go('/map')),
        if (auth.isAuthenticated)
          IconButton(
            tooltip: context.l10n.myEvents,
            onPressed: () => context.go('/my-events'),
            icon: Icon(Icons.bookmark_border_rounded,
                color: _matches(path, '/my-events') ? AppColors.primary : null),
          ),
        if (auth.isAuthenticated)
          IconButton(
            tooltip: context.l10n.messages,
            onPressed: () => context.go('/messages'),
            icon: Icon(Icons.forum_outlined,
                color: _matches(path, '/messages') ? AppColors.primary : null),
          ),
        if (auth.isApprovedOrganizer)
          IconButton(
            tooltip: context.l10n.organizerDashboard,
            onPressed: () => context.go('/organizer'),
            icon: Icon(Icons.dashboard_outlined,
                color: _matches(path, '/organizer') ? AppColors.primary : null),
          ),
        SizedBox(width: 8),
        if (auth.isAuthenticated) const _DesktopNotificationBell(),
        SizedBox(width: 8),
        if (!auth.isAuthenticated)
          TextButton(
              onPressed: () => context.go('/login'),
              child: Text(context.l10n.signIn1))
        else
          IconButton(
            tooltip: context.l10n.profileTooltip,
            onPressed: () => context.go('/profile'),
            icon: Icon(Icons.account_circle_outlined),
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
        SizedBox(width: 28),
      ],
    );
  }
}

class _DesktopNavLink extends StatelessWidget {
  const _DesktopNavLink(
      {required this.label, required this.selected, required this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? AppColors.primary : null,
          minimumSize: Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          SizedBox(height: 4),
          AnimatedContainer(
              duration: Duration(milliseconds: 180),
              width: selected ? 18 : 0,
              height: 2,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9))),
        ]),
      );
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
