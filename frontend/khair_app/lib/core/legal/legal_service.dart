import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing legal document acceptances
class LegalService {
  static const String _termsVersionKey = 'terms_version_accepted';
  static const String _privacyVersionKey = 'privacy_version_accepted';
  static const String _organizerAgreementKey = 'organizer_agreement_accepted';
  
  /// Current version of Terms of Service
  static const String currentTermsVersion = '1.0.0';
  
  /// Current version of Privacy Policy
  static const String currentPrivacyVersion = '1.0.0';
  
  /// Current version of Organizer Agreement
  static const String currentOrganizerAgreementVersion = '1.0.0';

  final SharedPreferences _prefs;

  LegalService(this._prefs);

  /// Check if user has accepted current Terms of Service
  bool hasAcceptedTerms() {
    final acceptedVersion = _prefs.getString(_termsVersionKey);
    return acceptedVersion == currentTermsVersion;
  }

  /// Check if user has accepted current Privacy Policy
  bool hasAcceptedPrivacy() {
    final acceptedVersion = _prefs.getString(_privacyVersionKey);
    return acceptedVersion == currentPrivacyVersion;
  }

  /// Check if organizer has accepted current agreement
  bool hasAcceptedOrganizerAgreement() {
    final acceptedVersion = _prefs.getString(_organizerAgreementKey);
    return acceptedVersion == currentOrganizerAgreementVersion;
  }

  /// Check if user needs to accept any policies
  bool needsAcceptance() {
    return !hasAcceptedTerms() || !hasAcceptedPrivacy();
  }

  /// Record Terms of Service acceptance
  Future<void> acceptTerms() async {
    await _prefs.setString(_termsVersionKey, currentTermsVersion);
  }

  /// Record Privacy Policy acceptance
  Future<void> acceptPrivacy() async {
    await _prefs.setString(_privacyVersionKey, currentPrivacyVersion);
  }

  /// Record Organizer Agreement acceptance
  Future<void> acceptOrganizerAgreement() async {
    await _prefs.setString(_organizerAgreementKey, currentOrganizerAgreementVersion);
  }

  /// Accept all required policies
  Future<void> acceptAll() async {
    await acceptTerms();
    await acceptPrivacy();
  }

  /// Clear all acceptances (for testing or policy updates)
  Future<void> clearAcceptances() async {
    await _prefs.remove(_termsVersionKey);
    await _prefs.remove(_privacyVersionKey);
    await _prefs.remove(_organizerAgreementKey);
  }
}

/// Widget for Terms & Privacy acceptance
class TermsAcceptanceDialog extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback? onDeclined;

  const TermsAcceptanceDialog({
    super.key,
    required this.onAccepted,
    this.onDeclined,
  });

  @override
  State<TermsAcceptanceDialog> createState() => _TermsAcceptanceDialogState();
}

class _TermsAcceptanceDialogState extends State<TermsAcceptanceDialog> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  bool get _canProceed => _termsAccepted && _privacyAccepted;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms & Privacy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please review and accept our terms to continue.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            // Terms checkbox
            _buildCheckbox(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              label: 'I accept the ',
              linkText: 'Terms of Service',
              onLinkTap: () => _openTerms(context),
            ),
            
            const SizedBox(height: 12),
            
            // Privacy checkbox
            _buildCheckbox(
              value: _privacyAccepted,
              onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
              label: 'I accept the ',
              linkText: 'Privacy Policy',
              onLinkTap: () => _openPrivacy(context),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                if (widget.onDeclined != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDeclined,
                      child: const Text('Decline'),
                    ),
                  ),
                if (widget.onDeclined != null) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed ? widget.onAccepted : null,
                    child: const Text('Accept & Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String linkText,
    required VoidCallback onLinkTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: label),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PolicyViewDialog(
        title: 'Terms of Service',
        version: LegalService.currentTermsVersion,
      ),
    );
  }

  void _openPrivacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _PolicyViewDialog(
        title: 'Privacy Policy',
        version: LegalService.currentPrivacyVersion,
      ),
    );
  }
}

class _PolicyViewDialog extends StatelessWidget {
  final String title;
  final String version;

  const _PolicyViewDialog({
    required this.title,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$title (v$version)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _getPlaceholderText(title),
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlaceholderText(String type) {
    // Placeholder - actual legal text would be loaded from API/assets
    return '''
$type for Khair Platform

Last updated: February 2026
Version: $version

1. Introduction
Welcome to Khair. By using our platform, you agree to these terms.

2. User Responsibilities
Users must provide accurate information and use the platform responsibly.

3. Content Guidelines
All content must comply with our community guidelines and local laws.

4. Privacy
Your privacy is important to us. See our Privacy Policy for details.

5. Limitation of Liability
The platform is provided "as is" without warranties.

6. Changes to Terms
We may update these terms. Continued use constitutes acceptance.

7. Contact
For questions, contact support@khair.app
''';
  }
}

/// Organizer Agreement acceptance widget
class OrganizerAgreementDialog extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const OrganizerAgreementDialog({
    super.key,
    required this.onAccepted,
    required this.onDeclined,
  });

  @override
  State<OrganizerAgreementDialog> createState() => _OrganizerAgreementDialogState();
}

class _OrganizerAgreementDialogState extends State<OrganizerAgreementDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organizer Agreement',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'As an event organizer, you must agree to additional terms.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const SingleChildScrollView(
                child: Text(
                  '''Organizer Agreement

By becoming an organizer on Khair, you agree to:

1. Provide accurate information about yourself and your events.

2. Comply with all applicable laws and regulations for event hosting.

3. Respond to user inquiries and reports in a timely manner.

4. Not post misleading, fraudulent, or harmful content.

5. Accept responsibility for events you create and publish.

6. Allow platform administrators to moderate your content.

Violation of these terms may result in suspension or termination.
''',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Checkbox(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                ),
                const Expanded(
                  child: Text(
                    'I agree to the Organizer Agreement',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDeclined,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _accepted ? widget.onAccepted : null,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
