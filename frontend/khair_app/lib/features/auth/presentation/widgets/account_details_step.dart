import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';

/// Maps UI role IDs to backend role strings
String mapToBackendRole(String uiRole) {
  switch (uiRole) {
    case 'sheikh':
      return 'sheikh';
    case 'organization_mosque':
    case 'organization_quran':
    case 'organization':
      return 'organization';
    case 'community_organizer':
    case 'volunteer':
      return 'community_organizer';
    case 'new_muslim':
      return 'new_muslim';
    case 'student':
    case 'member':
    default:
      return 'student';
  }
}

/// Returns true if the role is an authority/organization role (full flow)
bool isAuthorityRole(String uiRole) {
  return const {
    'sheikh',
    'organization_mosque',
    'organization_quran',
    'organization',
    'community_organizer',
    'volunteer',
  }.contains(uiRole);
}

/// Step 2: Account Details — Dynamic fields based on role
class AccountDetailsStep extends StatelessWidget {
  final String selectedRole;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController nameController;
  final TextEditingController cityController;
  // Country selection widget (passed from parent — state is lifted)
  final Widget countryWidget;
  // Role-specific controllers
  final TextEditingController? specializationController;
  final TextEditingController? yearsController;
  final TextEditingController? socialController;
  final TextEditingController? orgNameController;
  final TextEditingController? phoneController;
  final TextEditingController? focusController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;

  const AccountDetailsStep({
    super.key,
    required this.selectedRole,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.nameController,
    required this.cityController,
    required this.countryWidget,
    this.specializationController,
    this.yearsController,
    this.socialController,
    this.orgNameController,
    this.phoneController,
    this.focusController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Your Account',
            style: KhairTypography.h1.copyWith(
              color: Colors.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            style: KhairTypography.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 28),

          // Common: name
          _buildField(
            controller: nameController,
            label: _nameLabel,
            icon: Icons.person_outline,
            validator: _requiredValidator('name'),
          ),
          const SizedBox(height: 14),

          // Common: email
          _buildField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Common: password
          _buildField(
            controller: passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              onPressed: onTogglePassword,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Common: confirm password
          _buildField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              onPressed: onToggleConfirm,
            ),
            validator: (v) {
              if (v != passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Common: country dropdown
          countryWidget,
          const SizedBox(height: 14),

          // Common: city
          _buildField(
            controller: cityController,
            label: 'City',
            icon: Icons.location_city,
            validator: _requiredValidator('city'),
          ),

          // Role-specific fields
          ..._buildRoleFields(),
        ],
      ),
    );
  }

  String get _subtitle {
    if (selectedRole == 'sheikh') {
      return 'Tell us about your teaching background';
    }
    if (selectedRole.startsWith('organization') || selectedRole == 'organization') {
      return 'Set up your organization\'s account';
    }
    if (selectedRole == 'community_organizer' || selectedRole == 'volunteer') {
      return 'Tell us about your community work';
    }
    return 'Just the basics to get you started';
  }

  String get _nameLabel {
    if (selectedRole.startsWith('organization') ||
        selectedRole == 'organization') {
      return 'Contact Person Name';
    }
    return 'Full Name';
  }

  List<Widget> _buildRoleFields() {
    switch (selectedRole) {
      case 'sheikh':
        return [
          const SizedBox(height: 14),
          _buildField(
            controller: specializationController!,
            label: 'Specialization',
            icon: Icons.star_outline,
            hint: 'e.g. Tafseer, Fiqh, Hadith',
            validator: _requiredValidator('specialization'),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: yearsController!,
            label: 'Years of Experience',
            icon: Icons.timeline,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: socialController!,
            label: 'Social Media (optional)',
            icon: Icons.link,
            hint: 'YouTube, Twitter, etc.',
          ),
        ];

      case 'organization_mosque':
      case 'organization_quran':
      case 'organization':
        return [
          const SizedBox(height: 14),
          _buildField(
            controller: orgNameController!,
            label: _orgLabel,
            icon: Icons.business,
            validator: _requiredValidator('organization name'),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: phoneController!,
            label: 'Phone (optional)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ];

      case 'community_organizer':
      case 'volunteer':
        return [
          const SizedBox(height: 14),
          _buildField(
            controller: orgNameController!,
            label: 'Community / Group Name',
            icon: Icons.groups_outlined,
            validator: _requiredValidator('community name'),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: focusController!,
            label: 'Focus Area',
            icon: Icons.interests_outlined,
            hint: 'e.g. Youth Events, Charity, Sports',
          ),
        ];

      default:
        // student, new_muslim, member — just common fields
        return [];
    }
  }

  String get _orgLabel {
    switch (selectedRole) {
      case 'organization_mosque':
        return 'Mosque Name';
      case 'organization_quran':
        return 'Center Name';
      default:
        return 'Organization Name';
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: KhairColors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KhairColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KhairColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String fieldName) {
    return (v) {
      if (v == null || v.trim().isEmpty) return 'Please enter your $fieldName';
      return null;
    };
  }
}
