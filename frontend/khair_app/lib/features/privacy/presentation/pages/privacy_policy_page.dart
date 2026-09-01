import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/seo/privacy_metadata.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../tokens/app_colors.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  void initState() {
    super.initState();
    setPrivacyPolicyMetadata();
  }

  @override
  void dispose() {
    resetPrivacyPolicyMetadata();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = PrivacyPolicyCopy.forLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 56),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PrivacyTopBar(copy: copy),
                    const SizedBox(height: 28),
                    _PrivacyHero(copy: copy),
                    const SizedBox(height: 18),
                    _PrivacyDocument(copy: copy),
                    const SizedBox(height: 22),
                    _PrivacyFooter(copy: copy),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyTopBar extends StatelessWidget {
  const _PrivacyTopBar({required this.copy});

  final PrivacyPolicyCopy copy;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 560;
    return Row(
      children: [
        const KhairBrand(size: 34, nameStyle: TextStyle(fontSize: 20)),
        const Spacer(),
        LanguageSwitcher(showLabel: wide),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => context.go('/'),
          tooltip: copy.backToKhair,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero({required this.copy});

  final PrivacyPolicyCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D171126),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.brandName,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            copy.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DateChip(label: copy.effectiveDate),
              _DateChip(label: copy.lastUpdated),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _PrivacyDocument extends StatelessWidget {
  const _PrivacyDocument({required this.copy});

  final PrivacyPolicyCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 560 ? 20 : 34,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < copy.sections.length; index++) ...[
            _PrivacySectionView(section: copy.sections[index]),
            if (index != copy.sections.length - 1)
              Divider(
                height: 36,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkDivider
                    : AppColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _PrivacySectionView extends StatelessWidget {
  const _PrivacySectionView({required this.section});

  final PrivacyPolicySection section;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          for (final paragraph in section.paragraphs) ...[
            Text(
              paragraph,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                  ),
            ),
            const SizedBox(height: 10),
          ],
          if (section.bullets.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final bullet in section.bullets)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bullet,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter({required this.copy});

  final PrivacyPolicyCopy copy;

  @override
  Widget build(BuildContext context) => Text(
        copy.footer,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
              height: 1.6,
            ),
      );
}

class PrivacyPolicySection {
  const PrivacyPolicySection(
    this.title, {
    this.paragraphs = const [],
    this.bullets = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

class PrivacyPolicyCopy {
  const PrivacyPolicyCopy({
    required this.brandName,
    required this.title,
    required this.subtitle,
    required this.effectiveDate,
    required this.lastUpdated,
    required this.backToKhair,
    required this.footer,
    required this.sections,
  });

  final String brandName;
  final String title;
  final String subtitle;
  final String effectiveDate;
  final String lastUpdated;
  final String backToKhair;
  final String footer;
  final List<PrivacyPolicySection> sections;

  static PrivacyPolicyCopy forLanguage(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return _arabic;
      case 'tr':
        return _turkish;
      default:
        return _english;
    }
  }

  static const _english = PrivacyPolicyCopy(
    brandName: 'KHAIR',
    title: 'Privacy Policy',
    subtitle:
        'This Privacy Policy explains how Khair collects, uses, shares, and protects information when you use the Khair application and services.',
    effectiveDate: 'Effective date: August 22, 2026',
    lastUpdated: 'Last updated: August 22, 2026',
    backToKhair: 'Back to Khair',
    footer: 'Khair · Privacy Policy · https://khair.it.com/privacy',
    sections: [
      PrivacyPolicySection(
        '1. Introduction',
        paragraphs: [
          'Khair is a community event discovery and participation service. In this policy, “Khair”, “we”, “our”, and “us” mean the Khair service and the people operating it. This policy applies to the Khair mobile application, web application, and related services that link to it.',
          'The policy is written from the data flows currently implemented in Khair’s production application. Some features and integrations are enabled only when the relevant production configuration is present; where that is the case, this policy says so.',
        ],
      ),
      PrivacyPolicySection(
        '2. Information We Collect',
        paragraphs: [
          'We collect information that you provide, information generated when you use Khair, and limited technical information needed to operate and secure the service. We do not collect every category for every user, and optional permissions can be declined.',
        ],
        bullets: [
          'Account information, including your name or display name, email address, password hash for email accounts, email-verification records, and information needed to authenticate with Google when you choose Google sign-in.',
          'Profile information, including your biography, city, country, profile location label, avatar, preferred language, gender where provided, and notification preferences.',
          'Organizer information, including organization name, description, website, phone number, contact email, city, country, logo, representative photo, application status, and verification materials where organizer functionality requires them.',
          'Event participation and activity, including events you save, reserve or join, registration status, attendance-related records, events you create or manage, organizer announcements, and public event views. Search and API requests may also appear in operational logs.',
          'User-generated content, including event titles, descriptions, dates, locations, guidelines, images, organizer profiles, owner posts, reviews, reports, and other content you submit.',
          'Messages and support communications, including support conversations, messages, conversation context, and image attachments sent to Khair Support.',
          'Location information when you grant permission. The app may send device coordinates to Khair to resolve a city and country for nearby-event discovery. If permission is unavailable, Khair may use the request IP address for an approximate city, country, and timezone lookup.',
          'Device and technical information, including IP address, request metadata, platform information used for push-token registration, authentication session metadata, request IDs, and security or performance logs.',
          'Push notification and device tokens when you authorize notifications on a supported mobile device. Khair stores the token, platform, and association with your account so it can deliver and deactivate notifications.',
          'Uploaded images and media, such as avatars, event covers, organizer logos or representative photos, support image attachments, and verification images or documents where the feature requires them.',
          'Usage and diagnostic information where enabled, including error reports, crash information, and sampled performance traces. The mobile and web clients disable Sentry collection unless a Sentry DSN is supplied in the release configuration, and the client sets Sentry’s default PII collection to false.',
        ],
      ),
      PrivacyPolicySection(
        '3. Account Information',
        paragraphs: [
          'To create and secure an account, Khair stores your email address, a password hash rather than your plain-text password, display name, verification state, role, and account timestamps. If you sign in with Google, Khair receives and verifies the Google identity information needed to create or link your Khair account, such as your email address, name, profile image, and provider subject identifier.',
        ],
      ),
      PrivacyPolicySection(
        '4. Profile Information',
        paragraphs: [
          'You may add or edit profile details such as a biography, city, country, location label, avatar, language, gender, and communication preferences. Some profile details may be shown to other users or organizers according to the feature’s visibility and event context.',
        ],
      ),
      PrivacyPolicySection(
        '5. Organizer Information',
        paragraphs: [
          'Organizer functionality requires additional information so Khair can review applications, protect the community, and provide event-management tools. This may include organization details, contact information, logos, representative photos, and supporting identity or organization documents. Verification documents are kept in private storage and are made available only through authorized review flows.',
        ],
      ),
      PrivacyPolicySection(
        '6. Event Participation and Activity',
        paragraphs: [
          'When you save, reserve, join, cancel, or attend an event, Khair records the event relationship and related status and timestamps. Organizers can access attendee information needed to run their event, including attendee email, display name, registration status, attendance status, and registration time, subject to the organizer tools and access controls.',
          'Khair also records event and organizer activity needed for discovery, recommendations, notifications, moderation, fraud prevention, and operational reliability. A public event page may increment an event view counter without identifying every viewer to the organizer.',
        ],
      ),
      PrivacyPolicySection(
        '7. User-Generated Content',
        paragraphs: [
          'Content you submit remains your responsibility. Khair stores and processes it to publish events or posts, facilitate participation, provide moderation and safety features, and respond to reports. Public content can be visible to other users; private submissions, such as verification documents, are restricted to the workflows that require them.',
        ],
      ),
      PrivacyPolicySection(
        '8. Messages and Support Communications',
        paragraphs: [
          'Khair stores support tickets, messages, status information, and permitted image attachments so the in-app support service can answer questions, hand conversations to support staff, and maintain a record of the request. Support conversations may first receive an AI-generated response and may be escalated to a human support agent.',
        ],
      ),
      PrivacyPolicySection(
        '9. Location Information',
        paragraphs: [
          'Khair requests location permission only for location-aware discovery and related event features. When permission is granted, the app can send latitude and longitude to Khair’s API, which reverse-geocodes it into a city, country, country code, and timezone. Khair caches the resolved location locally on the device for faster startup.',
          'When coordinates are not available, the API can use the client IP address to request an approximate city, country, country code, and timezone. Location is optional; you can continue using Khair after denying permission, although nearby-event features may be less relevant.',
        ],
      ),
      PrivacyPolicySection(
        '10. Device Information',
        paragraphs: [
          'Khair receives ordinary request and security information such as IP address, request path, timing, status, request ID, and authentication-session metadata. The mobile notification flow also records whether a registered push token belongs to iOS or Android. We use this information for authentication, abuse prevention, troubleshooting, and service reliability, not for advertising profiles.',
        ],
      ),
      PrivacyPolicySection(
        '11. Push Notification Device Tokens',
        paragraphs: [
          'If you grant notification permission, Firebase Cloud Messaging provides a device token. Khair associates that token with your signed-in account to deliver event updates, announcements, reminders, and account or support notifications. Signing out or deleting an account asks Khair to deactivate the current token. You can also disable notifications in your device settings.',
        ],
      ),
      PrivacyPolicySection(
        '12. Uploaded Images and Media',
        paragraphs: [
          'Khair accepts images for avatars, event covers, organizer applications, and support attachments. Organizer verification can also require document uploads. Production media storage uses Cloudflare R2 when the production storage configuration is active; public media and private verification material use separate storage paths and access controls. Khair validates supported file types and size limits before upload.',
        ],
      ),
      PrivacyPolicySection(
        '13. Usage and Diagnostic Information',
        paragraphs: [
          'The API records operational logs and metrics such as request IDs, paths, response status, timing, IP address, and, where authenticated, an account identifier. If Sentry is enabled for a release, Khair sends application errors and sampled performance traces to Sentry with default PII collection disabled. These records help us detect abuse, investigate failures, and improve reliability and performance.',
        ],
      ),
      PrivacyPolicySection(
        '14. How We Use Information',
        paragraphs: [
          'Khair uses information only for purposes connected to the service, including:',
        ],
        bullets: [
          'Authentication, account verification, session management, and account security.',
          'Providing Khair services, including event discovery, public event pages, registrations, saved events, organizer tools, support, and account settings.',
          'Event discovery and recommendations, including location-aware results and AI-assisted ranking when enabled.',
          'Event participation, attendee management, attendance tracking, organizer announcements, and reminders.',
          'Notifications and communication, including verification email, transactional email, in-app notifications, and push delivery where enabled.',
          'Safety, moderation, reporting, organizer verification, fraud prevention, abuse prevention, and enforcement of our policies.',
          'AI-powered functionality such as event ranking, description assistance, content moderation, and support responses when those features are used and enabled.',
          'Improving reliability, performance, security, and the quality of Khair’s features.',
          'Complying with legal obligations, responding to lawful requests, and protecting the rights and safety of users and Khair.',
        ],
      ),
      PrivacyPolicySection(
        '15. Legal and Operational Basis Where Applicable',
        paragraphs: [
          'Depending on where you use Khair, we process information to provide the service you request, perform our contract with you, obtain consent for optional permissions such as location and notifications, pursue legitimate interests such as security and service improvement, and comply with legal obligations. You can withdraw permission for optional device features through your device or browser settings, but this does not affect processing that already occurred lawfully.',
        ],
      ),
      PrivacyPolicySection(
        '16. Information Sharing',
        paragraphs: [
          'Khair does not sell your personal information. We share information only when needed to provide a feature, protect users, operate the service, or comply with law.',
        ],
        bullets: [
          'Event organizers receive the attendee information needed to manage their events, including the fields made available in the organizer attendee tools.',
          'Other users can see information you choose to publish in a public profile, event, post, review, or report workflow.',
          'Authorized Khair staff and moderators can access information needed for support, verification, safety, moderation, and administration.',
          'Service providers process information on Khair’s instructions for hosting, storage, authentication, email, push delivery, location resolution, AI, and diagnostics.',
          'We may disclose information when required by law or when necessary to protect users, Khair, or the public from harm, fraud, or abuse.',
        ],
      ),
      PrivacyPolicySection(
        '17. Service Providers',
        paragraphs: [
          'The current code and deployment configuration identify the following processors or infrastructure services. Some are conditional on production secrets or feature configuration:',
        ],
        bullets: [
          'Firebase Cloud Messaging for mobile push notification delivery and Firebase Hosting for the web application assets.',
          'Google OAuth endpoints for Google sign-in verification and Google account identity data used for authentication.',
          'Cloudflare R2 for production public media and private organizer-evidence storage when the R2 configuration is enabled.',
          'PostgreSQL database infrastructure and Redis-compatible infrastructure used by the Khair API for application data, caching, rate limits, and real-time fan-out. The exact managed Redis vendor is deployment-specific.',
          'OpenStreetMap Nominatim for reverse geocoding and place search, and ip-api.com for the approximate IP-based location fallback.',
          'Resend is the preferred email integration in the backend, with SendGrid support as a fallback. Email processing is active only when the corresponding production API key is configured.',
          'Google Gemini for AI-assisted ranking, event-description assistance, moderation, and support responses when the Gemini API key is configured.',
          'Sentry for error tracking and sampled performance diagnostics only when a Sentry DSN is configured; client-side default PII collection is disabled.',
        ],
      ),
      PrivacyPolicySection(
        '18. AI Providers',
        paragraphs: [
          'Khair uses Google Gemini in backend features that can rank events, assist with event descriptions, moderate content, or draft support responses. When you use an AI-powered feature, Khair sends the minimum relevant content and context needed for that feature. Do not include sensitive information that is not necessary for the request. AI output can be inaccurate and does not replace human review for safety or organizer decisions.',
        ],
      ),
      PrivacyPolicySection(
        '19. Data Retention',
        paragraphs: [
          'We retain information for as long as it is needed to provide Khair, maintain security, resolve disputes, enforce policies, meet legal obligations, and keep appropriate backups. Retention depends on the record and feature rather than one universal period.',
        ],
        bullets: [
          'Registration drafts are designed to expire after the configured draft lifetime, currently seven days in the API schema.',
          'Verification records, access tokens, refresh tokens, notification tokens, support records, event records, moderation records, and operational logs are retained according to their function and cleanup or security requirements.',
          'Backups and logs may continue to contain limited information until they are rotated or securely overwritten.',
          'Deleting an account does not necessarily remove information already shared publicly, included in lawful records, or held in backups immediately.',
        ],
      ),
      PrivacyPolicySection(
        '20. Data Security',
        paragraphs: [
          'Khair uses HTTPS for network communication, bcrypt password hashing, expiring JWT and refresh-token controls, authenticated API middleware, access-controlled private document links, file validation, rate limiting, and security logging. No method of storage or transmission is completely secure, so you should use a unique password and report suspected account or safety issues promptly.',
        ],
      ),
      PrivacyPolicySection(
        '21. User Rights',
        paragraphs: [
          'Subject to applicable law, you may request access to, correction of, or deletion of personal information, and you may object to or restrict certain processing. Khair includes an authenticated data-export endpoint and profile editing tools. Contact us if you need help exercising a right or if the in-app tools do not address your request.',
        ],
      ),
      PrivacyPolicySection(
        '22. Account and Data Deletion',
        paragraphs: [
          'The Khair app currently includes an in-app Delete Account action on the signed-in Profile page. Open Profile, choose Delete Account, review the warning, and confirm Delete Forever. The app removes the authenticated account through the protected profile endpoint, clears its local session, deactivates the current push token, and deletes application records including the profile, event registrations, saved events, notifications, and device-token record. Database relationships may also cascade to associated organizer and event records.',
          'The deletion action is irreversible. Some security, audit, support, public-content, legal, backup, or provider-held records may be retained or anonymized where necessary for the purposes described in this policy. If deletion fails or you cannot sign in, contact Khair using the address in the Contact Us section and include the account email and the request you are making; do not send your password.',
        ],
      ),
      PrivacyPolicySection(
        '23. Location Permissions',
        paragraphs: [
          'Location permission is optional. You can allow or deny it when your device or browser asks. You can later change the permission in device or browser settings. Khair does not need location permission to display this Privacy Policy or to browse the public policy page.',
        ],
      ),
      PrivacyPolicySection(
        '24. Camera and Photo Permissions',
        paragraphs: [
          'Khair requests camera or photo-library access only when you choose an image or document for an applicable feature, such as an avatar, event image, organizer application, verification submission, or support attachment. You can deny access and can change the permission later in your device settings. Files are uploaded only after you select and submit them.',
        ],
      ),
      PrivacyPolicySection(
        '25. Push Notifications',
        paragraphs: [
          'Push notifications are optional. If enabled, Khair uses Firebase Cloud Messaging and a registered device token to send event updates, reminders, announcements, and important account or support messages. You can turn notifications off in the device settings; doing so may prevent you from receiving time-sensitive updates.',
        ],
      ),
      PrivacyPolicySection(
        '26. Children’s Privacy',
        paragraphs: [
          'Khair is intended for people who are at least 13 years old and is not directed to children under 13. We do not knowingly collect personal information from a child under 13. If you believe a child has provided personal information, contact us so we can investigate and take appropriate action.',
        ],
      ),
      PrivacyPolicySection(
        '27. International Data Processing',
        paragraphs: [
          'Khair and its service providers may process information in countries other than the country where you live. Those countries may have different data-protection rules. We use the providers and safeguards available in our production architecture and take reasonable steps to protect information during international processing.',
        ],
      ),
      PrivacyPolicySection(
        '28. Changes to This Privacy Policy',
        paragraphs: [
          'We may update this policy when Khair’s features, processors, or legal obligations change. We will publish the updated policy at this URL, update the Last updated date, and provide additional notice where required. Your continued use of Khair after an update means the updated policy applies to future use, subject to applicable law.',
        ],
      ),
      PrivacyPolicySection(
        '29. Contact Us',
        paragraphs: [
          'For privacy questions, data-rights requests, account-deletion help, or concerns about this policy, contact Khair at hassanalwaqedi3@gmail.com. This address is the public contact currently present in Khair’s existing legal configuration. Khair should replace or confirm it with a dedicated support/privacy mailbox before final publication if that is the intended official contact.',
        ],
      ),
    ],
  );

  static const _arabic = PrivacyPolicyCopy(
    brandName: 'خير',
    title: 'سياسة الخصوصية',
    subtitle:
        'توضح هذه السياسة كيفية جمع خير للمعلومات واستخدامها ومشاركتها وحمايتها عند استخدام تطبيق وخدمات خير.',
    effectiveDate: 'تاريخ السريان: 22 أغسطس 2026',
    lastUpdated: 'آخر تحديث: 22 أغسطس 2026',
    backToKhair: 'العودة إلى خير',
    footer: 'خير · سياسة الخصوصية · https://khair.it.com/privacy',
    sections: [
      PrivacyPolicySection('1. المقدمة', paragraphs: [
        'خير خدمة لاكتشاف الفعاليات المجتمعية والمشاركة فيها. تنطبق هذه السياسة على تطبيق خير وتطبيق الويب والخدمات المرتبطة به التي تشير إليها.',
        'تستند هذه السياسة إلى تدفقات البيانات الموجودة حالياً في تطبيق خير. وقد تعمل بعض الخدمات الخارجية فقط عند تفعيل إعداداتها في بيئة الإنتاج.',
      ]),
      PrivacyPolicySection('2. المعلومات التي نجمعها', paragraphs: [
        'نجمع المعلومات التي تقدمها، والمعلومات الناتجة عن استخدامك لخير، ومعلومات تقنية محدودة لازمة لتشغيل الخدمة وحمايتها. لا نجمع كل فئة من كل مستخدم، ويمكن رفض الأذونات الاختيارية.',
      ], bullets: [
        'معلومات الحساب: الاسم أو اسم العرض، البريد الإلكتروني، تجزئة كلمة المرور، سجلات التحقق، ومعلومات تسجيل الدخول عبر Google عند اختيارك له.',
        'معلومات الملف الشخصي: النبذة، المدينة، الدولة، الموقع النصي، الصورة الشخصية، اللغة، الجنس عند تقديمه، وتفضيلات الإشعارات.',
        'معلومات المنظم: اسم الجهة ووصفها وموقعها ورقم الهاتف والبريد المخصص للتواصل والمدينة والدولة والشعار والصورة والمواد المطلوبة للتحقق.',
        'المشاركة والنشاط: الفعاليات المحفوظة أو المحجوزة أو المنضم إليها، حالة التسجيل والحضور، الفعاليات التي تنشئها أو تديرها، والإعلانات. قد تظهر طلبات البحث والتطبيق في سجلات التشغيل.',
        'المحتوى الذي تنشئه: عناوين الفعاليات ووصفها ومواقعها وصورها وملفات المنظم والمنشورات والتقييمات والبلاغات.',
        'الرسائل والدعم: محادثات الدعم ورسائله وسياق المحادثة والمرفقات المصورة.',
        'الموقع عند منح الإذن: قد نرسل إحداثيات الجهاز لتحويلها إلى مدينة ودولة لاكتشاف الفعاليات القريبة، أو نستخدم عنوان IP لتقدير الموقع عند عدم توفر الإحداثيات.',
        'معلومات الجهاز والتشخيص: عنوان IP وبيانات الطلب والمنصة المرتبطة بالتنبيهات وسجلات الأمان والأداء، ورمز جهاز الإشعارات عند تفعيله.',
        'الصور والوسائط المرفوعة: الصور الشخصية وصور الفعاليات والشعارات وصور الدعم وملفات التحقق عند الحاجة.',
      ]),
      PrivacyPolicySection('3. معلومات الحساب', paragraphs: [
        'نخزن البريد الإلكتروني وتجزئة كلمة المرور بدلاً من كلمة المرور النصية واسم العرض وحالة التحقق والدور. عند استخدام Google نتحقق من المعلومات اللازمة لإنشاء حسابك أو ربطه، مثل البريد والاسم والصورة ومعرّف الحساب لدى المزود.',
      ]),
      PrivacyPolicySection('4. معلومات الملف الشخصي', paragraphs: [
        'يمكنك إضافة أو تعديل النبذة والمدينة والدولة والموقع والصورة واللغة والجنس وتفضيلات التواصل. وقد تظهر بعض هذه المعلومات للآخرين وفقاً لإعدادات الظهور والسياق.',
      ]),
      PrivacyPolicySection('5. معلومات المنظم', paragraphs: [
        'تتطلب أدوات المنظم معلومات إضافية لمراجعة الطلبات وحماية المجتمع وإدارة الفعاليات، ومنها بيانات الجهة ووسائل التواصل والصور ووثائق الهوية أو الجهة. تحفظ وثائق التحقق في تخزين خاص ولا تتاح إلا لمسارات المراجعة المصرح بها.',
      ]),
      PrivacyPolicySection('6. المشاركة في الفعاليات والنشاط', paragraphs: [
        'عند حفظ فعالية أو حجزها أو الانضمام إليها أو إلغائها أو حضورها، نسجل العلاقة بالحجز والحالة والتواريخ. يمكن للمنظم الوصول إلى بيانات الحضور اللازمة لإدارة الفعالية، مثل البريد واسم العرض وحالة التسجيل والحضور ووقت التسجيل.',
        'نستخدم أيضاً نشاط الفعالية والمنظم للاكتشاف والتوصيات والإشعارات والإشراف ومنع الاحتيال والموثوقية التشغيلية.',
      ]),
      PrivacyPolicySection('7. المحتوى الذي ينشئه المستخدم', paragraphs: [
        'أنت مسؤول عن المحتوى الذي ترسله. نخزنه ونعالجه لنشر الفعاليات والمنشورات وتسهيل المشاركة والإشراف والسلامة والاستجابة للبلاغات. قد يكون المحتوى العام مرئياً للمستخدمين، بينما تقيد المستندات الخاصة بمساراتها اللازمة.',
      ]),
      PrivacyPolicySection('8. الرسائل ودعم المستخدم', paragraphs: [
        'نخزن تذاكر الدعم والرسائل والحالة والمرفقات المسموح بها لتقديم الدعم وتحويل المحادثة إلى موظف عند الحاجة والاحتفاظ بسجل الطلب. قد تبدأ المحادثة برد مولد بالذكاء الاصطناعي ثم تحول إلى موظف.',
      ]),
      PrivacyPolicySection('9. معلومات الموقع', paragraphs: [
        'إذن الموقع اختياري ويستخدم لاكتشاف الفعاليات القريبة. عند منحه يمكن إرسال خط العرض والطول إلى واجهة خير لتحويلهما إلى مدينة ودولة ورمز دولة ومنطقة زمنية، وتخزين النتيجة محلياً على الجهاز. وعند عدم توفر الإحداثيات قد يستخدم الخادم عنوان IP لتقدير المدينة والدولة والمنطقة الزمنية.',
      ]),
      PrivacyPolicySection('10. معلومات الجهاز', paragraphs: [
        'تصل إلى خير معلومات تشغيل وأمان عادية مثل عنوان IP ومسار الطلب ووقته وحالته ورقم الطلب وبيانات الجلسة. كما نسجل منصة رمز الإشعارات في الهاتف. نستخدم ذلك للأمان ومنع إساءة الاستخدام وتحسين الخدمة، وليس لإنشاء ملفات إعلانية.',
      ]),
      PrivacyPolicySection('11. رموز الإشعارات', paragraphs: [
        'عند تفعيل الإشعارات يوفر Firebase Cloud Messaging رمزاً للجهاز. نربطه بحسابك لإرسال تحديثات الفعاليات والتنبيهات والتذكيرات. عند تسجيل الخروج أو حذف الحساب نطلب تعطيل الرمز، ويمكنك إيقاف الإشعارات من إعدادات الجهاز.',
      ]),
      PrivacyPolicySection('12. الصور والوسائط المرفوعة', paragraphs: [
        'تقبل خير الصور للملفات الشخصية والفعاليات وطلبات المنظم ومرفقات الدعم، وقد تتطلب مراجعة المنظم مستندات. يستخدم الإنتاج Cloudflare R2 عند تفعيل الإعداد، مع فصل الوسائط العامة عن مواد التحقق الخاصة وضبط الوصول إليها.',
      ]),
      PrivacyPolicySection('13. الاستخدام والتشخيص', paragraphs: [
        'تسجل واجهة API سجلات ومقاييس تشغيل مثل رقم الطلب والمسار والحالة والوقت وعنوان IP ومعرّف الحساب عند تسجيل الدخول. وإذا تم تفعيل Sentry ترسل أخطاء التطبيق وآثار الأداء المحدودة مع تعطيل جمع البيانات الشخصية الافتراضي.',
      ]),
      PrivacyPolicySection('14. كيف نستخدم المعلومات', paragraphs: [
        'نستخدم المعلومات للمصادقة والتحقق وإدارة الحساب، وتقديم خدمات خير واكتشاف الفعاليات والتوصيات والمشاركة وأدوات المنظم والإشعارات والتواصل والدعم والسلامة والإشراف والذكاء الاصطناعي ومنع الاحتيال وتحسين الموثوقية والأداء والامتثال للقانون.',
      ]),
      PrivacyPolicySection('15. الأساس القانوني والتشغيلي حيثما ينطبق',
          paragraphs: [
            'نعالج المعلومات لتقديم الخدمة المطلوبة وتنفيذ عقدك، وبموافقتك على الأذونات الاختيارية، ولمصالح مشروعة مثل الأمان وتحسين الخدمة، وللالتزام بالواجبات القانونية. يمكنك سحب أذونات الموقع والإشعارات من إعدادات جهازك أو متصفحك.',
          ]),
      PrivacyPolicySection('16. مشاركة المعلومات', paragraphs: [
        'لا نبيع معلوماتك الشخصية. نشاركها عند الحاجة لتقديم ميزة أو حماية المستخدمين أو تشغيل الخدمة أو الالتزام بالقانون. قد يحصل المنظمون على بيانات الحضور اللازمة لإدارة فعالياتهم، وقد يرى الآخرون ما تختار نشره علناً، ويصل الموظفون المصرح لهم إلى ما يلزم للدعم والتحقق والسلامة.',
      ]),
      PrivacyPolicySection('17. مزودو الخدمة', paragraphs: [
        'تشير الشفرة وإعدادات النشر إلى Firebase Cloud Messaging وFirebase Hosting وGoogle OAuth وCloudflare R2 وPostgreSQL وRedis وOpenStreetMap Nominatim وip-api.com وResend أو SendGrid وGoogle Gemini وSentry. بعض هذه الخدمات مشروط بمفاتيح وإعدادات الإنتاج.',
      ]),
      PrivacyPolicySection('18. مزودو الذكاء الاصطناعي', paragraphs: [
        'تستخدم خير Google Gemini لترتيب الفعاليات ومساعدة وصفها والإشراف عليها وصياغة ردود الدعم عند تفعيل الميزة. نرسل الحد الأدنى من المحتوى والسياق اللازمين، وقد تكون النتائج غير دقيقة ولا تستبدل المراجعة البشرية في قرارات السلامة.',
      ]),
      PrivacyPolicySection('19. الاحتفاظ بالبيانات', paragraphs: [
        'نحتفظ بالمعلومات ما يلزم لتقديم الخدمة والأمان وحل النزاعات وتنفيذ السياسات والالتزامات القانونية والنسخ الاحتياطية. تختلف المدة حسب نوع السجل. تنتهي مسودات التسجيل وفق الإعداد الحالي بعد سبعة أيام، وقد تبقى السجلات الأمنية والنسخ الاحتياطية حتى دورة الحذف أو التدوير.',
      ]),
      PrivacyPolicySection('20. أمن البيانات', paragraphs: [
        'نستخدم HTTPS وتجزئة كلمات المرور وإدارة الرموز المنتهية ووسائط تحقق خاصة وضبط الوصول والتحقق من الملفات وتحديد المعدل وسجلات الأمان. لا توجد وسيلة تخزين أو نقل آمنة تماماً، لذلك استخدم كلمة مرور فريدة وأبلغ عن المشكلات.',
      ]),
      PrivacyPolicySection('21. حقوق المستخدم', paragraphs: [
        'وفق القانون المعمول به يمكنك طلب الوصول إلى معلوماتك أو تصحيحها أو حذفها أو الاعتراض على بعض المعالجة. توفر خير أدوات تعديل الملف ونقطة مصادقة لتصدير البيانات، ويمكنك التواصل معنا إذا احتجت مساعدة.',
      ]),
      PrivacyPolicySection('22. حذف الحساب والبيانات', paragraphs: [
        'يتضمن تطبيق خير حالياً خيار Delete Account في صفحة Profile للمستخدم المسجل. افتح Profile ثم اختر Delete Account وراجع التحذير واضغط Delete Forever. يحذف المسار الحساب وسجل الملف والتسجيلات والفعاليات المحفوظة والإشعارات وسجل رمز الجهاز، وقد تؤدي علاقات قاعدة البيانات إلى حذف سجلات المنظم والفعاليات المرتبطة. العملية نهائية، وقد تبقى سجلات الأمان أو القانون أو النسخ الاحتياطية أو مزود خارجي مدة لازمة.',
      ]),
      PrivacyPolicySection('23. أذونات الموقع', paragraphs: [
        'إذن الموقع اختياري ويمكن رفضه أو تغييره من إعدادات الجهاز أو المتصفح. لا تحتاج إلى إذن الموقع لقراءة سياسة الخصوصية أو تصفح صفحتها العامة.',
      ]),
      PrivacyPolicySection('24. أذونات الكاميرا والصور', paragraphs: [
        'نطلب الوصول للكاميرا أو مكتبة الصور فقط عندما تختار صورة أو مستنداً لميزة مناسبة مثل الصورة الشخصية أو صورة فعالية أو طلب منظم أو دعم. يمكنك رفض الإذن وتغييره لاحقاً.',
      ]),
      PrivacyPolicySection('25. الإشعارات الفورية', paragraphs: [
        'الإشعارات اختيارية وتستخدم Firebase Cloud Messaging لإرسال تحديثات الفعاليات والتذكيرات والإعلانات ورسائل الحساب أو الدعم. يمكن إيقافها من إعدادات الجهاز.',
      ]),
      PrivacyPolicySection('26. خصوصية الأطفال', paragraphs: [
        'خير موجه لمن أعمارهم 13 عاماً فأكثر وليس للأطفال دون 13 عاماً. لا نجمع عن قصد معلومات طفل دون 13 عاماً. تواصل معنا إذا اعتقدت أن طفلاً أرسل معلومات شخصية.',
      ]),
      PrivacyPolicySection('27. المعالجة الدولية', paragraphs: [
        'قد تعالج خير ومزودوها المعلومات في دول غير دولة إقامتك. نستخدم مزودي البنية الحالية ووسائل الحماية المتاحة ونبذل جهوداً معقولة لحماية المعلومات.',
      ]),
      PrivacyPolicySection('28. تغييرات السياسة', paragraphs: [
        'قد نحدث السياسة عند تغير ميزات خير أو مزوديها أو الالتزامات القانونية. ننشر النسخة الجديدة على هذا العنوان ونحدث تاريخ آخر تعديل ونقدم إشعاراً إضافياً عند الحاجة.',
      ]),
      PrivacyPolicySection('29. تواصل معنا', paragraphs: [
        'لأسئلة الخصوصية أو طلبات الحقوق أو مساعدة حذف الحساب، تواصل مع خير عبر hassanalwaqedi3@gmail.com. هذا العنوان موجود كجهة اتصال عامة في الإعداد القانوني الحالي، ويجب تأكيده أو استبداله بصندوق خصوصية مخصص قبل النشر النهائي إذا كان ذلك هو المقصود.',
      ]),
    ],
  );

  static const _turkish = PrivacyPolicyCopy(
    brandName: 'KHAIR',
    title: 'Gizlilik Politikası',
    subtitle:
        'Bu politika, Khair uygulamasını ve hizmetlerini kullandığınızda bilgilerin nasıl toplandığını, kullanıldığını, paylaşıldığını ve korunduğunu açıklar.',
    effectiveDate: 'Yürürlük tarihi: 22 Ağustos 2026',
    lastUpdated: 'Son güncelleme: 22 Ağustos 2026',
    backToKhair: "Khair'e dön",
    footer: 'Khair · Gizlilik Politikası · https://khair.it.com/privacy',
    sections: [
      PrivacyPolicySection('1. Giriş', paragraphs: [
        'Khair, topluluk etkinliklerini keşfetme ve bu etkinliklere katılma hizmetidir. Bu politika Khair mobil uygulaması, web uygulaması ve ona bağlantı veren ilgili hizmetler için geçerlidir.',
        'Politika, Khair üretim uygulamasında şu anda bulunan veri akışlarına dayanır. Bazı dış hizmetler yalnızca üretim ayarlarında etkinleştirildiğinde çalışır.',
      ]),
      PrivacyPolicySection('2. Topladığımız bilgiler', paragraphs: [
        'Sağladığınız bilgileri, Khair kullanımınızdan oluşan bilgileri ve hizmeti işletmek ve güvenceye almak için gereken sınırlı teknik bilgileri toplarız. Her kategori her kullanıcı için toplanmaz ve isteğe bağlı izinler reddedilebilir.',
      ], bullets: [
        'Hesap bilgileri: ad veya görünen ad, e-posta, parola özeti, doğrulama kayıtları ve Google ile giriş yaptığınızda gereken kimlik bilgileri.',
        'Profil bilgileri: biyografi, şehir, ülke, konum etiketi, avatar, tercih edilen dil, sağlanan cinsiyet ve bildirim tercihleri.',
        'Organizatör bilgileri: kuruluş adı, açıklama, web sitesi, telefon, iletişim e-postası, şehir, ülke, logo, temsilci fotoğrafı, başvuru durumu ve doğrulama materyalleri.',
        'Etkinlik katılımı ve etkinlikler: kaydettiğiniz, rezerve ettiğiniz veya katıldığınız etkinlikler, kayıt ve katılım durumu, yönettiğiniz etkinlikler ve duyurular. Arama ve API istekleri operasyon kayıtlarında görülebilir.',
        'Kullanıcı içeriği: etkinlik başlıkları, açıklamalar, konumlar, fotoğraflar, organizatör profilleri, gönderiler, değerlendirmeler ve bildirimler.',
        'Mesajlar ve destek: destek konuşmaları, mesajlar, konuşma bağlamı ve görüntü ekleri.',
        'İzin verdiğinizde konum: yakın etkinlikleri göstermek için koordinatlar şehre ve ülkeye çevrilebilir; koordinat yoksa yaklaşık IP konumu kullanılabilir.',
        'Cihaz ve teknik bilgiler: IP adresi, istek bilgileri, bildirim belirteci için platform, oturum bilgileri ve güvenlik veya performans kayıtları.',
        'Yüklenen medya: avatarlar, etkinlik kapakları, organizatör fotoğrafları, destek görselleri ve gerektiğinde doğrulama belgeleri.',
      ]),
      PrivacyPolicySection('3. Hesap bilgileri', paragraphs: [
        'E-posta hesabı için e-postanızı, düz metin parolanız yerine parola özetini, görünen adınızı, doğrulama durumunuzu ve rolünüzü saklarız. Google ile girişte hesabınızı oluşturmak veya bağlamak için gereken e-posta, ad, fotoğraf ve sağlayıcı kimliğini doğrularız.',
      ]),
      PrivacyPolicySection('4. Profil bilgileri', paragraphs: [
        'Biyografi, şehir, ülke, konum, fotoğraf, dil, cinsiyet ve iletişim tercihlerini ekleyebilir veya düzenleyebilirsiniz. Bazı bilgiler görünürlük ayarlarına ve etkinlik bağlamına göre gösterilebilir.',
      ]),
      PrivacyPolicySection('5. Organizatör bilgileri', paragraphs: [
        'Organizatör araçları başvuruları incelemek, topluluğu korumak ve etkinlik yönetimi sağlamak için ek bilgiler gerektirir. Doğrulama belgeleri özel depolamada tutulur ve yalnızca yetkili inceleme akışlarında kullanılabilir.',
      ]),
      PrivacyPolicySection('6. Etkinlik katılımı ve kullanım', paragraphs: [
        'Bir etkinliği kaydettiğinizde, rezerve ettiğinizde, katıldığınızda veya iptal ettiğinizde ilgili durumu ve zamanları kaydederiz. Organizatörler etkinliklerini yürütmek için gereken katılımcı e-postası, görünen ad, kayıt ve katılım durumu gibi bilgileri görebilir.',
        'Etkinlik ve organizatör etkinliğini keşif, öneriler, bildirimler, moderasyon, kötüye kullanım önleme ve güvenilirlik için de kullanırız.',
      ]),
      PrivacyPolicySection('7. Kullanıcı içeriği', paragraphs: [
        'Gönderdiğiniz içerikten siz sorumlusunuz. İçeriği yayınlamak, katılımı sağlamak, güvenlik ve moderasyon yapmak ve bildirimleri incelemek için saklarız. Genel içerik diğer kullanıcılara görünür olabilir; özel gönderimler gerekli akışlarla sınırlandırılır.',
      ]),
      PrivacyPolicySection('8. Mesajlar ve destek iletişimi', paragraphs: [
        'Destek taleplerini, mesajları, durum bilgilerini ve izin verilen görsel ekleri destek sağlamak ve gerektiğinde insan görevliye aktarmak için saklarız. Konuşma önce AI yanıtı alabilir ve sonra görevliye aktarılabilir.',
      ]),
      PrivacyPolicySection('9. Konum bilgisi', paragraphs: [
        'Konum izni isteğe bağlıdır ve yakın etkinlik keşfi için kullanılır. İzin verildiğinde enlem ve boylam Khair API’sine gönderilerek şehir, ülke, ülke kodu ve saat dilimine çevrilebilir; sonuç cihazda önbelleğe alınabilir. Koordinat yoksa sunucu IP adresiyle yaklaşık konum çözebilir.',
      ]),
      PrivacyPolicySection('10. Cihaz bilgileri', paragraphs: [
        'IP adresi, istek yolu, süresi, durumu, istek numarası ve oturum bilgileri gibi olağan teknik verileri alırız. Bildirim belirtecinin mobil platformunu da kaydederiz. Bunları güvenlik ve hizmet kalitesi için, reklam profili oluşturmak için değil, kullanırız.',
      ]),
      PrivacyPolicySection('11. Bildirim cihaz belirteçleri', paragraphs: [
        'Bildirimleri etkinleştirdiğinizde Firebase Cloud Messaging bir cihaz belirteci sağlar. Khair bunu hesabınızla ilişkilendirerek etkinlik güncellemeleri, hatırlatmalar ve duyurular gönderir. Çıkışta veya hesap silmede belirteci devre dışı bırakmayı isteriz.',
      ]),
      PrivacyPolicySection('12. Yüklenen fotoğraf ve medya', paragraphs: [
        'Avatar, etkinlik, organizatör başvurusu ve destek görselleri kabul edilir; organizatör doğrulaması belge gerektirebilir. Üretim yapılandırması etkinse medya için Cloudflare R2 kullanılır ve genel medya ile özel doğrulama materyalleri ayrılır.',
      ]),
      PrivacyPolicySection('13. Kullanım ve tanılama', paragraphs: [
        'API; istek numarası, yol, durum, süre, IP adresi ve giriş yapılmışsa hesap kimliği gibi operasyon kayıtları ve ölçümler tutar. Sentry etkinse uygulama hataları ve örneklenmiş performans izleri gönderilir; varsayılan kişisel veri toplama kapalıdır.',
      ]),
      PrivacyPolicySection('14. Bilgileri nasıl kullanırız', paragraphs: [
        'Bilgileri kimlik doğrulama, hesap yönetimi, etkinlik keşfi ve önerileri, katılım ve organizatör araçları, bildirimler, iletişim, destek, güvenlik, moderasyon, AI özellikleri, dolandırıcılık ve kötüye kullanım önleme, güvenilirlik, performans ve yasal yükümlülükler için kullanırız.',
      ]),
      PrivacyPolicySection('15. Geçerli olduğunda yasal ve operasyonel dayanak',
          paragraphs: [
            'Bilgileri istediğiniz hizmeti sunmak ve sözleşmemizi yürütmek, isteğe bağlı konum ve bildirim izinleri için onay almak, güvenlik ve hizmet geliştirme gibi meşru menfaatleri gözetmek ve yasal yükümlülüklere uymak için işleriz. İzinleri cihaz veya tarayıcı ayarlarından geri alabilirsiniz.',
          ]),
      PrivacyPolicySection('16. Bilgi paylaşımı', paragraphs: [
        'Kişisel bilgilerinizi satmayız. Bilgileri yalnızca özellik sağlamak, kullanıcıları korumak, hizmeti işletmek veya hukuka uymak için paylaşırız. Organizatörler gerekli katılımcı bilgilerini, diğer kullanıcılar ise sizin yayımladığınız genel içeriği görebilir; yetkili Khair çalışanları destek ve güvenlik için gereken bilgilere erişebilir.',
      ]),
      PrivacyPolicySection('17. Hizmet sağlayıcılar', paragraphs: [
        'Mevcut kod ve dağıtım yapılandırması Firebase Cloud Messaging ve Hosting, Google OAuth, Cloudflare R2, PostgreSQL, Redis, OpenStreetMap Nominatim, ip-api.com, Resend veya SendGrid, Google Gemini ve Sentry hizmetlerini tanımlar. Bazıları üretim anahtarlarına ve ayarlarına bağlıdır.',
      ]),
      PrivacyPolicySection('18. AI sağlayıcıları', paragraphs: [
        'Khair, etkinlik sıralaması, açıklama yardımı, moderasyon ve destek yanıtları için Google Gemini kullanabilir. Yalnızca gerekli içeriği ve bağlamı göndeririz. AI çıktısı hatalı olabilir ve güvenlik kararlarında insan incelemesinin yerini tutmaz.',
      ]),
      PrivacyPolicySection('19. Veri saklama', paragraphs: [
        'Bilgileri hizmet, güvenlik, anlaşmazlık çözümü, politika uygulaması, yasal yükümlülükler ve yedekler için gerekli olduğu sürece saklarız. Kayıt türüne göre süre değişir. Kayıt taslakları mevcut API ayarına göre yedi gün sonra sona erecek şekilde tasarlanmıştır; güvenlik kayıtları ve yedekler döngüleri tamamlanana kadar kalabilir.',
      ]),
      PrivacyPolicySection('20. Veri güvenliği', paragraphs: [
        'HTTPS, parola özeti, süresi dolan erişim kontrolleri, özel doğrulama depolaması, dosya doğrulama, hız sınırlama ve güvenlik kayıtları kullanırız. Hiçbir yöntem tamamen güvenli değildir; benzersiz parola kullanın ve sorunları bildirin.',
      ]),
      PrivacyPolicySection('21. Kullanıcı hakları', paragraphs: [
        'Geçerli hukuka göre kişisel bilgilerinize erişme, düzeltme veya silme ve bazı işlemlere itiraz etme hakkınız olabilir. Khair profil düzenleme ve kimlik doğrulamalı veri dışa aktarma akışları sağlar. Yardım için bizimle iletişime geçin.',
      ]),
      PrivacyPolicySection('22. Hesap ve veri silme', paragraphs: [
        'Khair uygulamasında giriş yapmış kullanıcı Profil sayfasındaki Delete Account seçeneğini kullanabilir. Profile > Delete Account adımlarını açıp uyarıyı inceleyin ve Delete Forever seçeneğini onaylayın. Hesap, profil, kayıtlar, kaydedilen etkinlikler, bildirimler ve cihaz belirteci kaydı silinir; veritabanı ilişkileri organizatör ve etkinlik kayıtlarını da silebilir. İşlem geri alınamaz; bazı güvenlik, hukuk, yedek veya sağlayıcı kayıtları gerekli süre tutulabilir.',
      ]),
      PrivacyPolicySection('23. Konum izinleri', paragraphs: [
        'Konum izni isteğe bağlıdır ve cihaz veya tarayıcı ayarlarından reddedilebilir ya da değiştirilebilir. Gizlilik Politikasını okumak için konum izni gerekmez.',
      ]),
      PrivacyPolicySection('24. Kamera ve fotoğraf izinleri', paragraphs: [
        'Kamera veya fotoğraf kitaplığına yalnızca avatar, etkinlik fotoğrafı, organizatör başvurusu, doğrulama veya destek eki gibi uygun bir özellik için dosya seçtiğinizde erişiriz. İzni reddedebilir ve sonra ayarlardan değiştirebilirsiniz.',
      ]),
      PrivacyPolicySection('25. Anlık bildirimler', paragraphs: [
        'Bildirimler isteğe bağlıdır. Firebase Cloud Messaging ile etkinlik güncellemeleri, hatırlatmalar, duyurular ve hesap veya destek mesajları gönderilir. Bildirimleri cihaz ayarlarından kapatabilirsiniz.',
      ]),
      PrivacyPolicySection('26. Çocukların gizliliği', paragraphs: [
        'Khair en az 13 yaşındaki kişilere yöneliktir ve 13 yaşından küçük çocuklara yönelik değildir. 13 yaşından küçük bir çocuktan bilerek kişisel bilgi toplamayız. Böyle bir durum olduğunu düşünüyorsanız bize ulaşın.',
      ]),
      PrivacyPolicySection('27. Uluslararası veri işleme', paragraphs: [
        'Khair ve sağlayıcıları bilgileri yaşadığınız ülke dışındaki ülkelerde işleyebilir. Mevcut üretim mimarisindeki sağlayıcıları ve korumaları kullanır, bilgileri korumak için makul adımlar atarız.',
      ]),
      PrivacyPolicySection('28. Politikadaki değişiklikler', paragraphs: [
        'Khair özellikleri, sağlayıcıları veya yasal yükümlülükleri değiştiğinde politikayı güncelleyebiliriz. Güncel sürümü bu URL’de yayımlar ve Son güncelleme tarihini değiştiririz.',
      ]),
      PrivacyPolicySection('29. Bize ulaşın', paragraphs: [
        'Gizlilik soruları, veri hakkı talepleri veya hesap silme yardımı için hassanalwaqedi3@gmail.com adresinden Khair’e ulaşın. Bu adres mevcut yasal yapılandırmada genel iletişim adresi olarak bulunur; nihai yayından önce özel bir gizlilik/destek posta kutusu olarak doğrulanması veya değiştirilmesi gerekir.',
      ]),
    ],
  );
}
