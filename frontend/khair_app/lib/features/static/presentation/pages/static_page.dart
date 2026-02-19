import 'package:flutter/material.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';

/// Static Trust Pages - About, Policies, Terms
class StaticPage extends StatelessWidget {
  final String pageType;

  const StaticPage({
    super.key,
    required this.pageType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(24),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (pageType) {
      case 'about':
        return 'About Khair';
      case 'verification':
        return 'Verification Policy';
      case 'content':
        return 'Content Policy';
      case 'privacy':
        return 'Privacy Policy';
      case 'terms':
        return 'Terms of Use';
      default:
        return 'Khair';
    }
  }

  Widget _buildContent() {
    switch (pageType) {
      case 'about':
        return const _AboutContent();
      case 'verification':
        return const _VerificationPolicyContent();
      case 'content':
        return const _ContentPolicyContent();
      case 'privacy':
        return const _PrivacyPolicyContent();
      case 'terms':
        return const _TermsOfUseContent();
      default:
        return const _AboutContent();
    }
  }
}

class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero section
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [KhairColors.primarySurface, KhairColors.surfaceVariant],
            ),
            borderRadius: KhairRadius.large,
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: KhairColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'خ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khair', style: KhairTypography.displaySmall),
                    const SizedBox(height: 4),
                    Text(
                      'Connecting Muslim Communities Worldwide',
                      style: KhairTypography.bodyLarge.copyWith(
                        color: KhairColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        _buildSection(
          'Our Mission',
          'Khair is a platform dedicated to connecting Muslim communities around the world. We provide a trusted space for discovering Islamic events, mosques, and community centers in your area.',
        ),

        _buildSection(
          'What We Do',
          '''• Event Discovery: Find lectures, classes, community gatherings, and more
• Verified Organizers: All event organizers are vetted for authenticity
• Global Reach: Access events from communities worldwide
• Trust & Safety: Content is moderated to maintain community standards''',
        ),

        _buildSection(
          'Our Values',
          '''Authenticity: We verify all organizers to ensure trust
Community: We believe in strengthening local Muslim communities
Accessibility: Our platform is free and open to everyone
Privacy: We respect and protect your personal information''',
        ),

        _buildSection(
          'Contact Us',
          'For questions, feedback, or support, please reach out to:\n\nEmail: support@khair.app',
        ),
      ],
    );
  }
}

class _VerificationPolicyContent extends StatelessWidget {
  const _VerificationPolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification Policy', style: KhairTypography.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Last updated: February 2026',
          style: KhairTypography.bodyMedium,
        ),

        const SizedBox(height: 32),

        _buildSection(
          'Overview',
          'Khair verifies all event organizers to maintain trust and authenticity on our platform. This policy explains who can apply, what we verify, and how the process works.',
        ),

        _buildSection(
          'Who Can Apply',
          '''• Mosques and prayer spaces
• Islamic centers and community centers
• Educational institutions (schools, universities)
• Registered non-profit organizations
• Established community groups''',
        ),

        _buildSection(
          'Verification Requirements',
          '''1. Valid organization details (name, address, contact)
2. Proof of legitimacy (website, social media, registration)
3. Designated contact person
4. Agreement to our Terms of Service and Content Policy''',
        ),

        _buildSection(
          'Review Process',
          '''1. Submit application with required information
2. Our team reviews your submission (2-3 business days)
3. You receive email notification of the decision
4. If approved, you can publish events immediately
5. If rejected, you may reapply after addressing concerns''',
        ),

        _buildSection(
          'Maintaining Verified Status',
          '''• Comply with our Content Policy
• Respond to reports and inquiries
• Keep organization information up to date
• Publish accurate event information''',
        ),

        _buildSection(
          'Revocation',
          'Verified status may be revoked for policy violations, inactivity, or providing false information.',
        ),
      ],
    );
  }
}

class _ContentPolicyContent extends StatelessWidget {
  const _ContentPolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Content Policy', style: KhairTypography.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Last updated: February 2026',
          style: KhairTypography.bodyMedium,
        ),

        const SizedBox(height: 32),

        _buildSection(
          'Purpose',
          'This policy ensures Khair remains a trusted, respectful, and safe platform for all users.',
        ),

        _buildSection(
          'Allowed Content',
          '''• Islamic educational events and lectures
• Community gatherings and social events
• Prayer services and religious observances
• Charity and volunteer activities
• Cultural and interfaith events''',
        ),

        _buildSection(
          'Prohibited Content',
          '''• Hate speech or discrimination
• Violence or incitement
• Fraudulent or misleading information
• Spam or commercial advertising
• Political campaigning
• Content promoting illegal activities
• Harassment or personal attacks''',
        ),

        _buildSection(
          'Event Guidelines',
          '''• Provide accurate event details
• Use appropriate titles and descriptions
• Include correct date, time, and location
• Specify if registration is required
• Update or cancel events promptly''',
        ),

        _buildSection(
          'Reporting',
          'Users can report content that violates this policy. Reports are reviewed within 24-48 hours.',
        ),

        _buildSection(
          'Enforcement',
          '''• First violation: Warning
• Repeated violations: Content removal
• Serious violations: Account suspension
• Severe violations: Permanent ban''',
        ),
      ],
    );
  }
}

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privacy Policy', style: KhairTypography.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Last updated: February 2026',
          style: KhairTypography.bodyMedium,
        ),

        const SizedBox(height: 32),

        _buildSection(
          'Introduction',
          'Khair respects your privacy and is committed to protecting your personal information. This policy explains how we collect, use, and protect your data.',
        ),

        _buildSection(
          'Information We Collect',
          '''Account Information:
• Name and email address
• Organization details (for organizers)
• Profile information you provide

Usage Information:
• Events you view or bookmark
• Search queries
• Device and browser information''',
        ),

        _buildSection(
          'How We Use Your Information',
          '''• Provide and improve our services
• Send important notifications
• Personalize your experience
• Ensure platform security
• Comply with legal requirements''',
        ),

        _buildSection(
          'Information Sharing',
          '''We do not sell your personal information. We may share data with:
• Service providers who help operate our platform
• Legal authorities when required by law
• Organizations you choose to interact with''',
        ),

        _buildSection(
          'Data Security',
          'We use industry-standard security measures to protect your data, including encryption and secure servers.',
        ),

        _buildSection(
          'Your Rights',
          '''• Access your personal information
• Correct inaccurate data
• Delete your account and data
• Export your data
• Opt out of marketing communications''',
        ),

        _buildSection(
          'Contact',
          'For privacy-related inquiries: privacy@khair.app',
        ),
      ],
    );
  }
}

class _TermsOfUseContent extends StatelessWidget {
  const _TermsOfUseContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms of Use', style: KhairTypography.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Last updated: February 2026',
          style: KhairTypography.bodyMedium,
        ),

        const SizedBox(height: 32),

        _buildSection(
          'Agreement',
          'By using Khair, you agree to these Terms of Use. If you do not agree, please do not use our services.',
        ),

        _buildSection(
          'Eligibility',
          'You must be at least 13 years old to use Khair. Users under 18 should have parental consent.',
        ),

        _buildSection(
          'Account Responsibilities',
          '''• Provide accurate information
• Keep your account secure
• Do not share account credentials
• Notify us of unauthorized access
• You are responsible for all activity under your account''',
        ),

        _buildSection(
          'Acceptable Use',
          '''You agree to:
• Comply with all applicable laws
• Follow our Content Policy
• Respect other users
• Not attempt to bypass security measures
• Not use automated tools without permission''',
        ),

        _buildSection(
          'Intellectual Property',
          'Khair and its content are protected by intellectual property laws. You may not copy, modify, or distribute our content without permission.',
        ),

        _buildSection(
          'Disclaimer',
          'Khair is provided "as is" without warranties. We are not responsible for event accuracy, organizer conduct, or third-party content.',
        ),

        _buildSection(
          'Limitation of Liability',
          'To the maximum extent permitted by law, Khair is not liable for any indirect, incidental, or consequential damages.',
        ),

        _buildSection(
          'Changes',
          'We may update these terms. Continued use after changes constitutes acceptance.',
        ),

        _buildSection(
          'Contact',
          'For questions about these terms: legal@khair.app',
        ),
      ],
    );
  }
}

Widget _buildSection(String title, String content) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: KhairTypography.headlineSmall),
        const SizedBox(height: 8),
        Text(
          content,
          style: KhairTypography.bodyLarge.copyWith(
            height: 1.7,
            color: KhairColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
