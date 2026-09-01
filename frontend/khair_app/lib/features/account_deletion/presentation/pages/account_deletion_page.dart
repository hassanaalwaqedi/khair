import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/seo/account_deletion_metadata.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../tokens/app_colors.dart';

const _supportEmail = 'hassanalwaqedi3@gmail.com';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  @override
  void initState() {
    super.initState();
    setAccountDeletionMetadata();
  }

  @override
  void dispose() {
    resetAccountDeletionMetadata();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AccountDeletionCopy.forLanguage(
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
                    _AccountTopBar(copy: copy),
                    const SizedBox(height: 28),
                    _AccountHero(copy: copy),
                    const SizedBox(height: 18),
                    _DeletionSteps(copy: copy),
                    const SizedBox(height: 18),
                    _WarningCard(copy: copy),
                    const SizedBox(height: 18),
                    _DataDeletionCard(copy: copy),
                    const SizedBox(height: 18),
                    _HelpCard(copy: copy),
                    const SizedBox(height: 22),
                    Text(
                      copy.footer,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            height: 1.6,
                          ),
                    ),
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

class _AccountTopBar extends StatelessWidget {
  const _AccountTopBar({required this.copy});

  final AccountDeletionCopy copy;

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

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.copy});

  final AccountDeletionCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _LegalCard(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: AppColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                    const SizedBox(height: 6),
                    Text(
                      copy.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            copy.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.65,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              copy.publicNotice,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletionSteps extends StatelessWidget {
  const _DeletionSteps({required this.copy});

  final AccountDeletionCopy copy;

  @override
  Widget build(BuildContext context) => _LegalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              icon: Icons.phone_android_outlined,
              title: copy.stepsTitle,
            ),
            const SizedBox(height: 8),
            Text(
              copy.stepsIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < copy.steps.length; index++)
              _StepRow(number: index + 1, text: copy.steps[index]),
          ],
        ),
      );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.copy});

  final AccountDeletionCopy copy;

  @override
  Widget build(BuildContext context) => _LegalCard(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A191D)
            : const Color(0xFFFFF5F6),
        borderColor: AppColors.error.withValues(alpha: .28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.warningTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.warningBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DataDeletionCard extends StatelessWidget {
  const _DataDeletionCard({required this.copy});

  final AccountDeletionCopy copy;

  @override
  Widget build(BuildContext context) => _LegalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              icon: Icons.delete_sweep_outlined,
              title: copy.dataTitle,
            ),
            const SizedBox(height: 10),
            Text(
              copy.dataIntro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 14),
            for (final bullet in copy.dataBullets) _DataBullet(text: bullet),
            const SizedBox(height: 18),
            Text(
              copy.retentionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              copy.retentionBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
          ],
        ),
      );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.copy});

  final AccountDeletionCopy copy;

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': copy.supportSubject},
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) => _LegalCard(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceElevated
            : const Color(0xFFF8F5FF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              icon: Icons.support_agent_outlined,
              title: copy.helpTitle,
            ),
            const SizedBox(height: 9),
            Text(
              copy.helpBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              _supportEmail,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _contactSupport,
              icon: const Icon(Icons.mail_outline),
              label: Text(copy.contactButton),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 26),
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 560
            ? 20
            : padding.horizontal / 2,
        vertical: padding.vertical / 2,
      ),
      decoration: BoxDecoration(
        color: color ?? (dark ? AppColors.darkSurface : AppColors.surface),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              borderColor ?? (dark ? AppColors.darkBorder : AppColors.border),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08171126),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 25),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _DataBullet extends StatelessWidget {
  const _DataBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child:
                  Icon(Icons.check_circle, size: 17, color: AppColors.success),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                    ),
              ),
            ),
          ],
        ),
      );
}

class AccountDeletionCopy {
  const AccountDeletionCopy({
    required this.brandName,
    required this.title,
    required this.subtitle,
    required this.publicNotice,
    required this.stepsTitle,
    required this.stepsIntro,
    required this.steps,
    required this.warningTitle,
    required this.warningBody,
    required this.dataTitle,
    required this.dataIntro,
    required this.dataBullets,
    required this.retentionTitle,
    required this.retentionBody,
    required this.helpTitle,
    required this.helpBody,
    required this.contactButton,
    required this.supportSubject,
    required this.backToKhair,
    required this.footer,
  });

  final String brandName;
  final String title;
  final String subtitle;
  final String publicNotice;
  final String stepsTitle;
  final String stepsIntro;
  final List<String> steps;
  final String warningTitle;
  final String warningBody;
  final String dataTitle;
  final String dataIntro;
  final List<String> dataBullets;
  final String retentionTitle;
  final String retentionBody;
  final String helpTitle;
  final String helpBody;
  final String contactButton;
  final String supportSubject;
  final String backToKhair;
  final String footer;

  static AccountDeletionCopy forLanguage(String languageCode) {
    if (languageCode == 'ar') return _arabic;
    return _english;
  }

  static const _english = AccountDeletionCopy(
    brandName: 'KHAIR',
    title: 'Delete Your Khair Account',
    subtitle:
        'Khair provides a permanent, self-service way to delete your Khair account and the personal data associated with it. This information page is public so you can review the process even when you are signed out or do not have a Khair account.',
    publicNotice: 'Public account-deletion information for Khair',
    stepsTitle: 'Delete your account from the Khair app',
    stepsIntro:
        'Use the account controls in the Khair mobile application. You must be signed in to confirm deletion.',
    steps: [
      'Sign in to Khair.',
      'Open Profile.',
      'Go to account settings.',
      'Select “Delete Account”.',
      'Review the deletion warning.',
      'Select “Delete Forever” to confirm.',
    ],
    warningTitle: 'Deletion is permanent',
    warningBody:
        'After you select “Delete Forever”, the deletion cannot be undone and your account cannot be restored. The app signs you out after a successful deletion.',
    dataTitle: 'What happens to your Khair data',
    dataIntro:
        'The existing Khair account-deletion flow removes the account records it owns and the associated records handled by the deletion service, including:',
    dataBullets: [
      'User profile information: your Khair profile record is deleted.',
      'Email and account information: your Khair account record and login credentials are deleted.',
      'Saved events: saved-event relationships associated with your account are deleted.',
      'Event registrations: your event-registration records are deleted.',
      'User preferences: preferences stored with your account or profile are removed where applicable.',
      'Associated account data: notifications and the registered push-token association are deleted; related records are handled according to Khair’s data relationships.',
    ],
    retentionTitle: 'Information that may remain',
    retentionBody:
        'Khair does not promise a single fixed retention period for every record. Limited information may remain or be anonymized where needed for legal obligations, security and fraud prevention, moderation, dispute handling, public-content integrity, or backups. The account-deletion action itself does not guarantee immediate removal from operational logs, provider systems, or backups.',
    helpTitle: 'Need help?',
    helpBody:
        'If you cannot sign in, cannot find the setting, or the deletion request fails, contact Khair support. Include the email address for the Khair account and describe the problem. Never send your password.',
    contactButton: 'Email Khair support',
    supportSubject: 'Khair account deletion help',
    backToKhair: 'Back to Khair',
    footer:
        'Khair · Account deletion · https://khair-it-app.web.app/account-deletion',
  );

  static const _arabic = AccountDeletionCopy(
    brandName: 'خير',
    title: 'حذف حسابك في خير',
    subtitle:
        'يوفر تطبيق خير طريقة ذاتية ودائمة لحذف حساب خير والبيانات الشخصية المرتبطة به. هذه الصفحة عامة حتى تتمكن من مراجعة الخطوات دون تسجيل الدخول أو حتى دون امتلاك حساب في خير.',
    publicNotice: 'معلومات عامة عن حذف حساب خير',
    stepsTitle: 'حذف حسابك من تطبيق خير',
    stepsIntro:
        'استخدم إعدادات الحساب داخل تطبيق خير. يجب تسجيل الدخول لتأكيد الحذف.',
    steps: [
      'سجّل الدخول إلى خير.',
      'افتح الملف الشخصي.',
      'انتقل إلى إعدادات الحساب.',
      'اختر «حذف الحساب».',
      'راجع تحذير الحذف.',
      'اختر «حذف نهائي» للتأكيد.',
    ],
    warningTitle: 'الحذف نهائي',
    warningBody:
        'بعد اختيار «حذف نهائي»، لا يمكن التراجع عن الحذف أو استعادة الحساب. يسجّل التطبيق خروجك بعد نجاح الحذف.',
    dataTitle: 'ماذا يحدث لبياناتك في خير؟',
    dataIntro:
        'تحذف آلية حذف الحساب الحالية في خير سجلات الحساب والبيانات المرتبطة التي تديرها خدمة الحذف، ومنها:',
    dataBullets: [
      'معلومات الملف الشخصي: يُحذف سجل ملفك الشخصي في خير.',
      'البريد الإلكتروني ومعلومات الحساب: يُحذف سجل الحساب وبيانات تسجيل الدخول.',
      'الفعاليات المحفوظة: تُحذف العلاقات الخاصة بالفعاليات المحفوظة.',
      'تسجيلات الفعاليات: تُحذف سجلات تسجيلك في الفعاليات.',
      'التفضيلات: تُحذف التفضيلات المخزنة مع الحساب أو الملف الشخصي عند انطباق ذلك.',
      'البيانات المرتبطة بالحساب: تُحذف الإشعارات وارتباط رمز الإشعارات بالحساب، وتُعالج السجلات الأخرى وفق علاقات بيانات خير.',
    ],
    retentionTitle: 'معلومات قد تبقى',
    retentionBody:
        'لا تَعِد خير بمدة احتفاظ ثابتة واحدة لكل السجلات. قد تبقى معلومات محدودة أو تُجهّل عند الحاجة للالتزامات القانونية أو الأمان ومنع الاحتيال أو الإشراف أو معالجة النزاعات أو سلامة المحتوى العام أو النسخ الاحتياطية. ولا يضمن حذف الحساب إزالتها فوراً من السجلات التشغيلية أو أنظمة مقدمي الخدمة أو النسخ الاحتياطية.',
    helpTitle: 'هل تحتاج إلى مساعدة؟',
    helpBody:
        'إذا تعذر عليك تسجيل الدخول أو لم تجد الإعداد أو فشل طلب الحذف، فتواصل مع دعم خير. اذكر البريد الإلكتروني للحساب واشرح المشكلة، ولا ترسل كلمة المرور.',
    contactButton: 'مراسلة دعم خير',
    supportSubject: 'المساعدة في حذف حساب خير',
    backToKhair: 'العودة إلى خير',
    footer: 'خير · حذف الحساب · https://khair-it-app.web.app/account-deletion',
  );
}
