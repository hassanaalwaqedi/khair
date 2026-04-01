import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../sheikh/presentation/bloc/sheikh_bloc.dart';

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
              // Verification prompt for pending organizers/sheikhs
              if (state.isOrganizer && !state.isApprovedOrganizer)
                SliverToBoxAdapter(
                  child: _buildVerificationBanner(context, isDark),
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
              // Delete account
              SliverToBoxAdapter(
                child: _buildDeleteAccountSection(context),
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

  // â”€â”€â”€ Signed-Out State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSignedOutState(BuildContext context, bool isDark) {
    return _AnimatedGuestLanding(isDark: isDark);
  }

  // â”€â”€â”€ Profile Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                context.l10n.profile,
                style: KhairTypography.h2.copyWith(color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () async {
                  final result = await context.push('/profile/edit');
                  if (result == true) {
                    // Refresh sheikh list so community view reflects changes
                    try {
                      context.read<SheikhBloc>().add(const LoadSheikhs());
                    } catch (_) {}
                    // Also refresh auth state to update profile data
                    try {
                      context.read<AuthBloc>().add(CheckAuthStatus());
                    } catch (_) {}
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit Profile',
              ),
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

  // â”€â”€â”€ Stats Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                  label: context.l10n.memberSince,
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
                      ? context.l10n.roleOrganizer
                      : state.isAdmin
                          ? context.l10n.roleAdmin
                          : context.l10n.roleMember,
                  label: context.l10n.accountType,
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
                  value: state.isApprovedOrganizer ? context.l10n.statusActive : context.l10n.statusBasic,
                  label: context.l10n.status,
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

  // â”€â”€â”€ Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildQuickActions(
      BuildContext context, AuthState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.quickActions,
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
                  label: context.l10n.organizerDashboard,
                  color: KhairColors.primary,
                  isDark: isDark,
                  onTap: () => context.go('/organizer'),
                ),
              if (state.isApprovedOrganizer)
                _QuickActionCard(
                  icon: Icons.add_circle_outline,
                  label: context.l10n.createEvent,
                  color: KhairColors.info,
                  isDark: isDark,
                  onTap: () => context.go('/organizer/events/create'),
                ),
              if (!state.isOrganizer && !state.isSheikh)
                _QuickActionCard(
                  icon: Icons.star_outline_rounded,
                  label: context.l10n.becomeOrganizer,
                  color: KhairColors.secondary,
                  isDark: isDark,
                  onTap: () => context.go('/organizer/apply'),
                ),
              if (!state.isOrganizer && !state.isSheikh && !state.isAdmin)
                _QuickActionCard(
                  icon: Icons.menu_book_rounded,
                  label: context.l10n.myLearning,
                  color: KhairColors.info,
                  isDark: isDark,
                  onTap: () => context.go('/my-learning'),
                ),
              if (state.isSheikh)
                _QuickActionCard(
                  icon: Icons.school_rounded,
                  label: 'Sheikh Dashboard',
                  color: KhairColors.primary,
                  isDark: isDark,
                  onTap: () => context.go('/sheikh-dashboard'),
                ),
              if (state.isAdmin)
                _QuickActionCard(
                  icon: Icons.admin_panel_settings_outlined,
                  label: context.l10n.adminPanel,
                  color: KhairColors.error,
                  isDark: isDark,
                  onTap: () => context.go('/admin'),
                ),
              if (state.isAdmin)
                _QuickActionCard(
                  icon: Icons.article_outlined,
                  label: context.l10n.ownerDashboard,
                  color: KhairColors.secondary,
                  isDark: isDark,
                  onTap: () => context.go('/owner-dashboard'),
                ),
              _QuickActionCard(
                icon: Icons.explore_outlined,
                label: context.l10n.browseEvents,
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

  // â”€â”€â”€ Account Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAccountSection(
      BuildContext context, AuthState state, bool isDark) {
    final user = state.user!;
    return _Section(
      title: context.l10n.accountInformation,
      isDark: isDark,
      children: [
        _InfoRow(
          icon: Icons.email_outlined,
          label: context.l10n.email,
          value: user.email,
          isDark: isDark,
        ),
        _InfoRow(
          icon: Icons.badge_outlined,
          label: context.l10n.role,
          value: user.role[0].toUpperCase() + user.role.substring(1),
          isDark: isDark,
        ),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: context.l10n.memberSince,
          value: DateFormat('MMMM dd, yyyy').format(user.createdAt),
          isDark: isDark,
        ),
      ],
    );
  }

  // â”€â”€â”€ Organizer Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildOrganizerSection(
      BuildContext context, AuthState state, bool isDark) {
    final organizer = state.organizer!;
    return _Section(
      title: context.l10n.organizerProfile,
      isDark: isDark,
      children: [
        _InfoRow(
          icon: Icons.business,
          label: context.l10n.organization,
          value: organizer.name,
          isDark: isDark,
        ),
        _InfoRow(
          icon: Icons.verified_outlined,
          label: context.l10n.status,
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
            label: context.l10n.website,
            value: organizer.website!,
            isDark: isDark,
          ),
        if (organizer.phone != null)
          _InfoRow(
            icon: Icons.phone_outlined,
            label: context.l10n.phone,
            value: organizer.phone!,
            isDark: isDark,
          ),
      ],
    );
  }

  // â”€â”€â”€ Verification Banner â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildVerificationBanner(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GestureDetector(
        onTap: () => context.push('/verification'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KhairColors.warning.withValues(alpha: 0.12),
                KhairColors.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: KhairColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: KhairColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: KhairColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify Your Account',
                      style: KhairTypography.labelLarge.copyWith(
                        color: isDark
                            ? KhairColors.darkTextPrimary
                            : KhairColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your ID & certificate to get verified',
                      style: KhairTypography.bodySmall.copyWith(
                        color: isDark
                            ? KhairColors.darkTextSecondary
                            : KhairColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: KhairColors.warning,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€ Sign Out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                title: Text(context.l10n.signOutConfirmTitle),
                content: Text(context.l10n.signOutConfirmMessage),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.l10n.cancel),
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
                    child: Text(context.l10n.signOut),
                  ),
                ],
              ),
            );
          },
          icon: Icon(Icons.logout, color: KhairColors.error),
          label: Text(
            context.l10n.signOut,
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

  Widget _buildDeleteAccountSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => _showDeleteAccountDialog(context),
          icon: Icon(Icons.delete_forever, color: KhairColors.error, size: 18),
          label: Text(
            context.l10n.deleteAccountTitle,
            style: TextStyle(
              color: KhairColors.error.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteAccountTitle),
        content: Text(context.l10n.deleteAccountWarning),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final apiClient = getIt<ApiClient>();
                await apiClient.delete('/me');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.deleteAccountSuccess)),
                  );
                  context.read<AuthBloc>().add(LogoutRequested());
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.deleteAccountError)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(context.l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Reusable Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final String text;
  final Color color;
  final Color cardBg;
  final Color border;
  final Color tp;

  const _BenefitCard({
    required this.icon,
    required this.emoji,
    required this.text,
    required this.color,
    required this.cardBg,
    required this.border,
    required this.tp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tp,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}

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

// --- Animated Guest Landing ---

class _AnimatedGuestLanding extends StatefulWidget {
  final bool isDark;
  const _AnimatedGuestLanding({required this.isDark});

  @override
  State<_AnimatedGuestLanding> createState() => _AnimatedGuestLandingState();
}

class _AnimatedGuestLandingState extends State<_AnimatedGuestLanding>
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  late final AnimationController _floatController;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;

    return SafeArea(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: KhairColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.mosque, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('Khair', style: TextStyle(fontSize: 20, color: tp, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  const LanguageSwitcher(showLabel: false),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 280, height: 280,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_orbitController, _pulseController, _floatController]),
                    builder: (context, _) {
                      final ps = 1.0 + (_pulseController.value * 0.08);
                      final po = (0.15 - (_pulseController.value * 0.08)).clamp(0.03, 0.15);
                      final rs = 1.0 + ((1.0 - _pulseController.value) * 0.06);
                      final fy = -8.0 + (_floatController.value * 16.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(scale: ps, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KhairColors.primary.withValues(alpha: po), width: 1.5)))),
                          Transform.scale(scale: rs, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: KhairColors.secondary.withValues(alpha: 0.08), width: 1)))),
                          ..._buildDots(),
                          Transform.translate(
                            offset: Offset(0, fy),
                            child: Container(
                              width: 110, height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B5F50), Color(0xFF1C7A66), Color(0xFF2D8E75)]),
                                boxShadow: [BoxShadow(color: KhairColors.primary.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)],
                              ),
                              child: const Icon(Icons.mosque_rounded, size: 48, color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Column(
                children: [
                  Text('Khair', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: tp, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text(context.l10n.guestHeroSubtitle, style: TextStyle(fontSize: 15, color: ts, height: 1.5), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/register'),
                      style: ElevatedButton.styleFrom(backgroundColor: KhairColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text(context.l10n.guestGetStarted, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton(
                      onPressed: () => context.go('/login'),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: KhairColors.primary.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: Text(context.l10n.guestAlreadyHaveAccount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: KhairColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDots() {
    const offsets = [0.0, 0.33, 0.66, 0.5, 0.83];
    const radii = [120.0, 120.0, 120.0, 90.0, 90.0];
    const sizes = [10.0, 7.0, 8.0, 6.0, 5.0];
    final colors = [KhairColors.primary, KhairColors.secondary, KhairColors.accent, KhairColors.info, KhairColors.primary];
    return List.generate(5, (i) {
      final angle = (_orbitController.value + offsets[i]) * 2 * math.pi;
      final x = radii[i] * math.cos(angle);
      final y = radii[i] * math.sin(angle) * 0.4;
      return Transform.translate(
        offset: Offset(x, y),
        child: Container(
          width: sizes[i], height: sizes[i],
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors[i].withValues(alpha: 0.6),
            boxShadow: [BoxShadow(color: colors[i].withValues(alpha: 0.3), blurRadius: 8)],
          ),
        ),
      );
    });
  }
}
