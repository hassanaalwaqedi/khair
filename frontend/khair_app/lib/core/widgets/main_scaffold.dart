import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../tokens/tokens.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import '../locale/l10n_extension.dart';

/// Main scaffold with a floating glassmorphic bottom nav.
/// 5 tabs: Discover · Map · Chat · Dashboard · Profile
class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xDD1A1F26)
                    : const Color(0xE6FFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    label: context.l10n.navDiscover,
                    isSelected: _selectedIndex(context) == 0,
                    onTap: () => context.go('/'),
                  ),
                  _NavItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: context.l10n.navMap,
                    isSelected: _selectedIndex(context) == 1,
                    onTap: () => context.go('/map'),
                  ),
                  // Chat tab with unread badge
                  BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, chatState) {
                      final totalUnread = chatState.conversations.fold<int>(
                        0, (sum, c) => sum + c.unreadCount,
                      );
                      return _NavItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        activeIcon: Icons.chat_bubble_rounded,
                        label: context.l10n.navChat,
                        isSelected: _selectedIndex(context) == 2,
                        badgeCount: totalUnread,
                        onTap: () => context.go('/conversations'),
                      );
                    },
                  ),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: context.l10n.navDashboard,
                    isSelected: _selectedIndex(context) == 3,
                    onTap: () => _handleDashboardTap(context),
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person,
                    label: context.l10n.navProfile,
                    isSelected: _selectedIndex(context) == 4,
                    onTap: () => context.go('/profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/map')) return 1;
    if (location.startsWith('/conversations')) return 2;
    if (location.startsWith('/organizer') ||
        location.startsWith('/admin') ||
        location.startsWith('/sheikh-dashboard')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _handleDashboardTap(BuildContext context) {
    final authState = context.read<AuthBloc>().state;

    // Not logged in → go to login
    if (authState.status != AuthStatus.authenticated || authState.user == null) {
      context.go('/login');
      return;
    }

    // Admin → go to admin dashboard
    if (authState.isAdmin) {
      context.go('/admin');
      return;
    }

    // Organizer → go to organizer dashboard
    if (authState.isOrganizer) {
      context.go('/organizer');
      return;
    }

    // Sheikh → go to sheikh dashboard
    if (authState.isSheikh) {
      context.go('/sheikh-dashboard');
      return;
    }

    // Regular user → show become organizer dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.business_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.l10n.becomeOrganizerTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(
          context.l10n.becomeOrganizerDesc,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/organizer/apply');
            },
            icon: const Icon(Icons.add_business_rounded, size: 18),
            label: Text(context.l10n.register),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single nav item with animated icon + label + optional badge
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = AppColors.primary;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.4);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.isSelected ? widget.activeIcon : widget.icon,
                      key: ValueKey(widget.isSelected),
                      size: 24,
                      color: widget.isSelected ? selectedColor : unselectedColor,
                    ),
                  ),
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                        child: Text(
                          widget.badgeCount > 99 ? '99+' : '${widget.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected ? selectedColor : unselectedColor,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
