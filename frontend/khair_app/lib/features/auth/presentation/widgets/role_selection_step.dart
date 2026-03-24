import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Step 1: Role Selection — "How Will You Use Khair?"
class RoleSelectionStep extends StatelessWidget {
  final String? selectedRole;
  final ValueChanged<String> onRoleSelected;

  const RoleSelectionStep({
    super.key,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  List<_RoleOption> _getRoles(BuildContext context) {
    final l10n = context.l10n;
    return [
      _RoleOption(
        id: 'sheikh',
        label: l10n.registrationRoleSheikh,
        description: l10n.roleDescSheikh,
        icon: Icons.menu_book_rounded,
      ),
      _RoleOption(
        id: 'organization',
        label: l10n.registrationRoleOrganization,
        description: l10n.roleDescOrganization,
        icon: Icons.account_balance_rounded,
      ),
      _RoleOption(
        id: 'organization_mosque',
        label: l10n.registrationOrgTypeMosque,
        description: l10n.roleDescMosque,
        icon: Icons.mosque_rounded,
      ),
      _RoleOption(
        id: 'organization_quran',
        label: l10n.registrationOrgTypeQuranCenter,
        description: l10n.roleDescQuranCenter,
        icon: Icons.auto_stories_rounded,
      ),
      _RoleOption(
        id: 'student',
        label: l10n.registrationRoleStudent,
        description: l10n.roleDescStudent,
        icon: Icons.school_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.registrationRoleSelectionTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.registrationRoleSelectionSubtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(_getRoles(context).length, (index) {
          final role = _getRoles(context)[index];
          final isSelected = selectedRole == role.id;
          return Padding(
            padding: EdgeInsets.only(bottom: index < 4 ? 8 : 0),
            child: _RoleTile(
              role: role,
              isSelected: isSelected,
              onTap: () => onRoleSelected(role.id),
            ),
          );
        }),
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

/// Clean list-tile style role selector
class _RoleTile extends StatefulWidget {
  final _RoleOption role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : _hovering
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : _hovering
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.role.icon,
                  color: isSelected
                      ? AppColors.primaryLight
                      : Colors.white.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.role.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.role.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Check indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
