import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status == AuthStatus.unauthenticated) {
            context.go('/');
          }
        },
        builder: (context, state) {
          final user = state.user;

          if (state.status == AuthStatus.initial ||
              state.status == AuthStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (user == null) {
            return _buildSignedOutState(context, isDark);
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Header with gradient avatar
              SliverToBoxAdapter(
                child: _buildProfileHeader(context, state, isDark),
              ),
              // Stats row
              SliverToBoxAdapter(
                child: _buildStatsRow(context, state, isDark),
              ),
              // Quick actions
              SliverToBoxAdapter(
                child: _buildQuickActions(context, state, isDark),
              ),
              // Account info
              SliverToBoxAdapter(
                child: _buildAccountSection(context, state, isDark),
              ),
              // Organizer info
              if (state.organizer != null)
                SliverToBoxAdapter(
                  child: _buildOrganizerSection(context, state, isDark),
                ),
              // Sign out
              SliverToBoxAdapter(
                child: _buildSignOutButton(context, isDark),
              ),
              // Bottom spacing for floating nav
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Signed-Out State ────────────────────────────────

  Widget _buildSignedOutState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? KhairColors.darkSurfaceVariant
                    : KhairColors.surfaceVariant,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: KhairColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Khair',
              style: KhairTypography.h2.copyWith(
                color: isDark
                    ? KhairColors.darkTextPrimary
                    : KhairColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to manage your profile and events',
              style: KhairTypography.bodyMedium.copyWith(
                color: KhairColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text(
                'Create an account',
                style: TextStyle(
                  color: KhairColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Profile Header ──────────────────────────────────

  Widget _buildProfileHeader(
      BuildContext context, AuthState state, bool isDark) {
    final user = state.user!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 16,
        24,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B5F50),
            Color(0xFF1C7A66),
            Color(0xFF2D8E75),
          ],
        ),
      ),
      child: Column(
        children: [
          // Top actions bar
          Row(
            children: [
              Text(
                'Profile',
                style: KhairTypography.h2.copyWith(color: Colors.white),
              ),
              const Spacer(),
              const LanguageSwitcher(showLabel: false),
            ],
          ),
          const SizedBox(height: 28),

          // Avatar with gradient ring
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  KhairColors.secondary,
                  KhairColors.secondaryLight,
                  KhairColors.secondary,
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFF1C7A66),
              child: Text(
                user.email[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Email
          Text(
            user.email,
            style: KhairTypography.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _roleIcon(user.role),
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  user.role[0].toUpperCase() + user.role.substring(1),
                  style: KhairTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, AuthState state, bool isDark) {
    final user = state.user!;
    final memberSince = DateFormat('MMM yyyy').format(user.createdAt);

    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? KhairColors.darkCard : KhairColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? KhairColors.darkBorder : KhairColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  value: memberSince,
                  label: 'Member Since',
                  icon: Icons.calendar_today_rounded,
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? KhairColors.darkBorder : KhairColors.border,
              ),
              Expanded(
                child: _StatItem(
                  value: state.isOrganizer
                      ? 'Organizer'
                      : state.isAdmin
                          ? 'Admin'
                          : 'Member',
                  label: 'Account Type',
                  icon: Icons.shield_outlined,
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? KhairColors.darkBorder : KhairColors.border,
              ),
              Expanded(
                child: _StatItem(
                  value: state.isApprovedOrganizer ? 'Active' : 'Basic',
                  label: 'Status',
                  icon: Icons.verified_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick Actions ───────────────────────────────────

  Widget _buildQuickActions(
      BuildContext context, AuthState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: KhairTypography.headlineSmall.copyWith(
              color:
                  isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              if (state.isApprovedOrganizer)
                _QuickActionCard(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  color: KhairColors.primary,
                  isDark: isDark,
                  onTap: () => context.go('/organizer'),
                ),
              if (state.isApprovedOrganizer)
                _QuickActionCard(
                  icon: Icons.add_circle_outline,
                  label: 'Create Event',
                  color: KhairColors.info,
                  isDark: isDark,
                  onTap: () => context.go('/organizer/events/create'),
                ),
              if (!state.isOrganizer)
                _QuickActionCard(
                  icon: Icons.star_outline_rounded,
                  label: 'Become Organizer',
                  color: KhairColors.secondary,
                  isDark: isDark,
                  onTap: () => context.go('/organizer/apply'),
                ),
              if (state.isAdmin)
                _QuickActionCard(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin Panel',
                  color: KhairColors.error,
                  isDark: isDark,
                  onTap: () => context.go('/admin'),
                ),
              _QuickActionCard(
                icon: Icons.explore_outlined,
                label: 'Browse Events',
                color: KhairColors.accent,
                isDark: isDark,
                onTap: () => context.go('/'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Account Section ─────────────────────────────────

  Widget _buildAccountSection(
      BuildContext context, AuthState state, bool isDark) {
    final user = state.user!;
    return _Section(
      title: 'Account Information',
      isDark: isDark,
      children: [
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email,
          isDark: isDark,
        ),
        _InfoRow(
          icon: Icons.badge_outlined,
          label: 'Role',
          value: user.role[0].toUpperCase() + user.role.substring(1),
          isDark: isDark,
        ),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Member since',
          value: DateFormat('MMMM dd, yyyy').format(user.createdAt),
          isDark: isDark,
        ),
      ],
    );
  }

  // ─── Organizer Section ───────────────────────────────

  Widget _buildOrganizerSection(
      BuildContext context, AuthState state, bool isDark) {
    final organizer = state.organizer!;
    return _Section(
      title: 'Organizer Profile',
      isDark: isDark,
      children: [
        _InfoRow(
          icon: Icons.business,
          label: 'Organization',
          value: organizer.name,
          isDark: isDark,
        ),
        _InfoRow(
          icon: Icons.verified_outlined,
          label: 'Status',
          value:
              organizer.status[0].toUpperCase() + organizer.status.substring(1),
          isDark: isDark,
          valueColor: organizer.isApproved
              ? KhairColors.success
              : organizer.isPending
                  ? KhairColors.warning
                  : KhairColors.error,
        ),
        if (organizer.website != null)
          _InfoRow(
            icon: Icons.language,
            label: 'Website',
            value: organizer.website!,
            isDark: isDark,
          ),
        if (organizer.phone != null)
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: organizer.phone!,
            isDark: isDark,
          ),
      ],
    );
  }

  // ─── Sign Out ────────────────────────────────────────

  Widget _buildSignOutButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<AuthBloc>().add(LogoutRequested());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KhairColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
          },
          icon: Icon(Icons.logout, color: KhairColors.error),
          label: Text(
            'Sign Out',
            style: TextStyle(
              color: KhairColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: KhairColors.error.withValues(alpha: 0.4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'organizer':
        return Icons.business;
      default:
        return Icons.person;
    }
  }
}

// ─── Reusable Widgets ────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isDark;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: KhairColors.primary,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: KhairTypography.labelLarge.copyWith(
            color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: KhairTypography.labelSmall.copyWith(
            color: KhairColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark
                ? KhairColors.darkCard
                : KhairColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark
                  ? KhairColors.darkBorder
                  : KhairColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: KhairTypography.labelMedium.copyWith(
                  color: widget.isDark
                      ? KhairColors.darkTextPrimary
                      : KhairColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final bool isDark;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? KhairColors.darkCard : KhairColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? KhairColors.darkBorder : KhairColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: KhairTypography.labelMedium.copyWith(
                color: KhairColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KhairColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: KhairTypography.labelSmall.copyWith(
                    color: KhairColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: KhairTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor ??
                        (isDark
                            ? KhairColors.darkTextPrimary
                            : KhairColors.textPrimary),
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
