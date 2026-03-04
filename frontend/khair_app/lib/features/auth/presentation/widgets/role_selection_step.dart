import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';

/// Step 1: Role Selection — "How Will You Use Khair?"
class RoleSelectionStep extends StatelessWidget {
  final String? selectedRole;
  final ValueChanged<String> onRoleSelected;

  const RoleSelectionStep({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  static const _roles = [
    _RoleOption(
      id: 'sheikh',
      label: 'Sheikh / Lecturer',
      description: 'Share Islamic knowledge and lead educational events',
      icon: Icons.menu_book_rounded,
    ),
    _RoleOption(
      id: 'organization_mosque',
      label: 'Mosque',
      description: 'Manage mosque activities and community prayers',
      icon: Icons.mosque_rounded,
    ),
    _RoleOption(
      id: 'organization_quran',
      label: 'Quran Memorization Center',
      description: 'Organize Quran study circles and hifz programs',
      icon: Icons.auto_stories_rounded,
    ),
    _RoleOption(
      id: 'organization',
      label: 'Islamic Organization',
      description: 'Run an Islamic charity, school, or institution',
      icon: Icons.account_balance_rounded,
    ),
    _RoleOption(
      id: 'community_organizer',
      label: 'Community Event Organizer',
      description: 'Plan social gatherings and community events',
      icon: Icons.groups_rounded,
    ),
    _RoleOption(
      id: 'student',
      label: 'Student',
      description: 'Discover and attend Islamic learning events',
      icon: Icons.school_rounded,
    ),
    _RoleOption(
      id: 'new_muslim',
      label: 'New Muslim',
      description: 'Find welcoming communities and beginner resources',
      icon: Icons.favorite_rounded,
    ),
    _RoleOption(
      id: 'volunteer',
      label: 'Volunteer',
      description: 'Help organize events and support the community',
      icon: Icons.volunteer_activism_rounded,
    ),
    _RoleOption(
      id: 'member',
      label: 'Regular Community Member',
      description: 'Browse and attend events in your area',
      icon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 3 : screenWidth > 550 ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How Will You Use Khair?',
          style: KhairTypography.h1.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the role that best describes you',
          style: KhairTypography.bodyLarge.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 28),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 3.2 : 1.8,
          ),
          itemCount: _roles.length,
          itemBuilder: (context, index) {
            final role = _roles[index];
            final isSelected = selectedRole == role.id;
            return _RoleCard(
              role: role,
              isSelected: isSelected,
              onTap: () => onRoleSelected(role.id),
            );
          },
        ),
      ],
    );
  }
}

class _RoleOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  const _RoleOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class _RoleCard extends StatefulWidget {
  final _RoleOption role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _pressed
              ? 0.95
              : _hovering
                  ? 1.02
                  : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? KhairColors.secondary
                    : _hovering
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.10),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: KhairColors.secondary.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KhairColors.secondary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.role.icon,
                        color: isSelected
                            ? KhairColors.secondary
                            : Colors.white.withValues(alpha: 0.8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.role.label,
                            style: KhairTypography.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.role.description,
                            style: KhairTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: KhairColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
