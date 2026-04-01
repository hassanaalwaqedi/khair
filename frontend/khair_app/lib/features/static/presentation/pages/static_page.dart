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
          'Last updated: March 2026',
          style: KhairTypography.bodyMedium,
        ),

        const SizedBox(height: 32),

        _buildSection(
          '1. Introduction',
          'Khair ("we", "our", or "us") operates the Khair mobile application and website (collectively, the "Service"). This Privacy Policy explains how we collect, use, disclose, and safeguard your personal information when you use our Service. By using Khair, you consent to the data practices described in this policy.',
        ),

        _buildSection(
          '2. Information We Collect',
          '''2.1 Account Information
When you register, we collect your name, email address, and password (stored securely using bcrypt hashing). Organizers and Sheikhs provide additional details such as organization name, bio, and contact information.

2.2 Location Data
With your permission, we collect precise location (GPS) and approximate location to show nearby events and mosques on the map. You can revoke location permission at any time via your device settings. Cached location is stored locally on your device using SharedPreferences.

2.3 Device Information
We collect your device type, operating system version, and a Firebase Cloud Messaging (FCM) token to send push notifications. The FCM token is a device identifier used solely for notification delivery.

2.4 Usage Data
We collect information about how you interact with the Service, including events viewed, searches performed, and pages visited.

2.5 Chat & Messaging Data
Messages sent through our in-app chat feature are stored on our servers to facilitate communication between students and sheikhs.

2.6 Crash & Performance Data
We use Sentry for crash reporting in production builds. Crash reports may include device model, OS version, app version, and error stack traces. We do not collect personally identifiable information (PII) through Sentry (sendDefaultPii is disabled).

2.7 Locally Stored Data
We store your language preference, theme preference, and legal document acceptance status locally on your device using SharedPreferences and Flutter Secure Storage. Authentication tokens are stored using encrypted secure storage.''',
        ),

        _buildSection(
          '3. How We Use Your Information',
          '''We use your information to:
• Provide, maintain, and improve the Service
• Create and manage your account
• Display nearby events and community resources
• Send push notifications about bookings, messages, and updates
• Facilitate communication between students and sheikhs
• Process event registrations and lesson bookings
• Monitor and analyze usage patterns to improve user experience
• Detect, prevent, and address technical issues and security threats
• Comply with legal obligations''',
        ),

        _buildSection(
          '4. Information Sharing & Disclosure',
          '''We do NOT sell, trade, or rent your personal information to third parties.

We may share your information with:
• Service Providers: Firebase (Google) for authentication and push notifications, Sentry for crash reporting — these providers are bound by their own privacy policies
• Event Organizers: When you register for an event, the organizer may see your name and email
• Sheikhs: When you book a lesson, the sheikh can see your name and booking details
• Law Enforcement: When required by law, regulation, or legal process
• Safety: When necessary to protect the safety of our users or the public''',
        ),

        _buildSection(
          '5. Data Security',
          '''We implement industry-standard security measures:
• Passwords are hashed using bcrypt
• Authentication tokens are stored in encrypted secure storage
• All data is transmitted over HTTPS/TLS
• JWT tokens expire after 24 hours
• API endpoints are protected with rate limiting
• Cleartext network traffic is disabled in the app

No method of electronic transmission or storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.''',
        ),

        _buildSection(
          '6. Data Retention',
          '''• Account data is retained while your account is active
• Chat messages are retained for the duration of the conversation
• Crash reports are retained for 90 days
• FCM tokens are removed when you log out or uninstall the app
• You may request deletion of your account and associated data at any time''',
        ),

        _buildSection(
          '7. Your Rights',
          '''You have the right to:
• Access: Request a copy of your personal data
• Correction: Update inaccurate or incomplete information via your profile
• Deletion: Request deletion of your account and personal data by contacting support@khair.app
• Portability: Request your data in a machine-readable format
• Withdraw Consent: Revoke location, notification, or other permissions via device settings
• Opt Out: Unsubscribe from non-essential notifications in app settings''',
        ),

        _buildSection(
          '8. Children\'s Privacy',
          'Khair is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we discover that we have collected data from a child under 13, we will delete it promptly. If you believe a child has provided us with personal information, please contact us at privacy@khair.app.',
        ),

        _buildSection(
          '9. Third-Party Services',
          '''Our Service integrates with the following third-party services, each governed by their own privacy policies:
• Firebase (Google) — Authentication, Cloud Messaging, Hosting
• Sentry — Crash reporting and error monitoring
• OpenStreetMap — Map tiles and geolocation services
• Nominatim — Reverse geocoding (location name lookup)''',
        ),

        _buildSection(
          '10. International Data Transfers',
          'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place in compliance with applicable data protection laws.',
        ),

        _buildSection(
          '11. Changes to This Policy',
          'We may update this Privacy Policy from time to time. We will notify you of material changes by posting the new policy on this page and updating the "Last updated" date. Your continued use of the Service after changes constitutes acceptance of the updated policy.',
        ),

        _buildSection(
          '12. Contact Us',
          '''If you have questions or concerns about this Privacy Policy, contact us at:

Email: privacy@khair.app
Website: https://khair.it.com/privacy''',
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
          'Last updated: March 2026',
          style: KhairTypography.bodyMedium,
        ),

        const SizedBox(height: 32),

        _buildSection(
          '1. Acceptance of Terms',
          'By downloading, installing, or using the Khair application ("Service"), you agree to be bound by these Terms of Use ("Terms"). If you do not agree to these Terms, do not use the Service. We may modify these Terms at any time; your continued use after changes constitutes acceptance.',
        ),

        _buildSection(
          '2. Eligibility',
          'You must be at least 13 years old to use Khair. If you are under 18, you must have the consent of a parent or legal guardian. By using the Service, you represent that you meet these age requirements.',
        ),

        _buildSection(
          '3. Account Registration',
          '''• You must provide accurate, current, and complete information during registration
• You are responsible for maintaining the confidentiality of your account credentials
• You are responsible for all activities that occur under your account
• You must notify us immediately of any unauthorized access to your account
• We reserve the right to suspend or terminate accounts that violate these Terms
• Email verification is required to activate your account''',
        ),

        _buildSection(
          '4. User Roles & Responsibilities',
          '''4.1 General Users
May browse events, view the map, register for events, book lessons with sheikhs, and use the chat feature.

4.2 Organizers
Must apply and be approved before publishing events. Organizers agree to provide accurate event information, comply with our Content Policy, and accept responsibility for events they create.

4.3 Sheikhs
Must be verified before offering lessons. Sheikhs agree to maintain their availability schedule, respond to booking requests, and conduct themselves professionally.

4.4 Administrators
Have authority to approve or reject organizer and sheikh applications, moderate content, and enforce platform policies.''',
        ),

        _buildSection(
          '5. Acceptable Use',
          '''You agree NOT to:
• Post false, misleading, or fraudulent content
• Harass, threaten, or intimidate other users
• Upload content that is hateful, violent, or discriminatory
• Use the Service for illegal purposes or to promote illegal activities
• Attempt to gain unauthorized access to other accounts or systems
• Use automated scripts, bots, or scrapers without written permission
• Circumvent or disable any security features of the Service
• Impersonate another person or entity
• Send spam or unsolicited communications through the platform''',
        ),

        _buildSection(
          '6. Content & Intellectual Property',
          '''6.1 Your Content
You retain ownership of content you create (event descriptions, messages, profile information). By posting content, you grant Khair a non-exclusive, worldwide license to display, distribute, and promote your content within the Service.

6.2 Our Content
The Khair name, logo, design, and software are owned by Khair and protected by intellectual property laws. You may not copy, modify, distribute, or reverse-engineer any part of the Service without our written consent.

6.3 Content Moderation
We reserve the right to review, moderate, and remove any content that violates these Terms or our Content Policy, at our sole discretion and without prior notice.''',
        ),

        _buildSection(
          '7. Bookings & Lessons',
          '''• Lesson bookings are arrangements between students and sheikhs
• Khair facilitates the booking process but is not a party to the arrangement
• We do not guarantee the quality, accuracy, or suitability of any lesson
• Users are responsible for honoring their booking commitments
• Cancellation policies are determined by individual sheikhs''',
        ),

        _buildSection(
          '8. Push Notifications',
          'By using the Service, you may receive push notifications about bookings, messages, and platform updates. You can disable notifications at any time through your device settings.',
        ),

        _buildSection(
          '9. Disclaimer of Warranties',
          '''THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED.

We do not warrant that:
• The Service will be uninterrupted, error-free, or secure
• Event information provided by organizers is accurate or complete
• Lessons provided by sheikhs meet any particular standard of quality
• The Service will meet your specific requirements''',
        ),

        _buildSection(
          '10. Limitation of Liability',
          '''TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, KHAIR SHALL NOT BE LIABLE FOR:
• Any indirect, incidental, special, consequential, or punitive damages
• Loss of data, revenue, profits, or business opportunities
• Damages arising from your use of or inability to use the Service
• Actions or omissions of third-party organizers, sheikhs, or other users
• Content posted by users on the platform

Our total liability shall not exceed the amount you paid us in the 12 months preceding the claim.''',
        ),

        _buildSection(
          '11. Indemnification',
          'You agree to indemnify and hold harmless Khair, its officers, directors, and employees from any claims, damages, or expenses arising from your use of the Service, your violation of these Terms, or your violation of any third-party rights.',
        ),

        _buildSection(
          '12. Termination',
          '''• You may delete your account at any time
• We may suspend or terminate your account for violation of these Terms
• Upon termination, your right to use the Service ceases immediately
• Provisions that by nature should survive termination (limitation of liability, indemnification, intellectual property) will remain in effect''',
        ),

        _buildSection(
          '13. Governing Law',
          'These Terms shall be governed by and construed in accordance with applicable laws. Any disputes arising from these Terms or your use of the Service shall be resolved through binding arbitration or in the courts of competent jurisdiction.',
        ),

        _buildSection(
          '14. Severability',
          'If any provision of these Terms is found to be unenforceable or invalid, that provision shall be modified to the minimum extent necessary, and the remaining provisions shall continue in full force and effect.',
        ),

        _buildSection(
          '15. Contact Us',
          '''For questions or concerns about these Terms, contact us at:

Email: legal@khair.app
Website: https://khair.it.com/terms''',
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
