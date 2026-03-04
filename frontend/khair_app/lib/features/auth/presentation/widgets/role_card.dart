import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Animated role selection card with icon, title, and description
class RoleCard extends StatelessWidget {
  final String role;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color:
                    isSelected ? theme.colorScheme.primary : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  /// Predefined role configurations with localization support
  static List<RoleCard> allRoles({
    required AppLocalizations l10n,
    required String? selectedRole,
    required void Function(String) onSelect,
  }) {
    final roles = [
      (
        role: 'organization',
        title: l10n.registrationRoleOrganization,
        desc: l10n.registrationRoleDescOrganization,
        icon: Icons.account_balance_outlined,
      ),
      (
        role: 'sheikh',
        title: l10n.registrationRoleSheikh,
        desc: l10n.registrationRoleDescSheikh,
        icon: Icons.school_outlined,
      ),
      (
        role: 'new_muslim',
        title: l10n.registrationRoleNewMuslim,
        desc: l10n.registrationRoleDescNewMuslim,
        icon: Icons.favorite_outline,
      ),
      (
        role: 'student',
        title: l10n.registrationRoleStudent,
        desc: l10n.registrationRoleDescStudent,
        icon: Icons.menu_book_outlined,
      ),
      (
        role: 'community_organizer',
        title: l10n.registrationRoleCommunityOrganizer,
        desc: l10n.registrationRoleDescCommunityOrganizer,
        icon: Icons.groups_outlined,
      ),
    ];

    return roles
        .map((r) => RoleCard(
              role: r.role,
              title: r.title,
              description: r.desc,
              icon: r.icon,
              isSelected: selectedRole == r.role,
              onTap: () => onSelect(r.role),
            ))
        .toList();
  }
}
