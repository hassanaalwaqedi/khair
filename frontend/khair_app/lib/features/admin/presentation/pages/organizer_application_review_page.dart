import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/organizer_application_admin_api.dart';

/// Full, auditable dossier view. All source data is fetched from the new
/// application API; document/image viewing first requests a signed URL from an
/// admin-only endpoint, which the backend records in the revision audit trail.
class OrganizerApplicationReviewPage extends StatefulWidget {
  const OrganizerApplicationReviewPage(
      {super.key, required this.applicationId});
  final String applicationId;

  @override
  State<OrganizerApplicationReviewPage> createState() =>
      _OrganizerApplicationReviewPageState();
}

class _OrganizerApplicationReviewPageState
    extends State<OrganizerApplicationReviewPage> {
  static const _pink = Color(0xfff43f75);
  final _api = OrganizerApplicationAdminApi();
  Map<String, dynamic>? _application;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final application = await _api.detail(widget.applicationId);
      if (mounted) {
        setState(() => _application = application);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'We could not load this organizer dossier.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _application == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.organizerApplication)),
        body: Center(
            child: FilledButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh),
                label: Text(context.l10n.tryAgain))),
      );
    }
    final app = _application!;
    final isPending = app['status'] == 'pending';
    return Scaffold(
      backgroundColor: Color(0xfffdfbfc),
      appBar: AppBar(
        title: Text(context.l10n.organizerApplication),
        actions: [
          IconButton(
              onPressed: _load,
              tooltip: context.l10n.refreshDossier,
              icon: Icon(Icons.refresh_rounded))
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 920),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(app),
                        SizedBox(height: 16),
                        _section('Applicant and public profile', [
                          _line('Organizer type',
                              _display(_string(app['organizer_type']))),
                          _line('Public name', _string(app['public_name'])),
                          _line('Responsible representative',
                              _string(app['representative_name'])),
                          _line('Account email', _string(app['account_email'])),
                          _line('Account email verified',
                              _yesNo(app['account_email_verified'] == true)),
                          _line('Organizer contact email',
                              _string(app['contact_email'])),
                          _line('Contact email verified',
                              _yesNo(app['contact_email_verified'] == true)),
                          _line('Phone',
                              _string(app['phone'], fallback: 'Not provided')),
                          _line('Location',
                              '${_string(app['city'])}, ${_string(app['country_code'])}'),
                          _line('Account created',
                              _date(app['account_created_at'])),
                          _line('Application submitted',
                              _date(app['submitted_at'])),
                          _line('Resubmitted', _date(app['resubmitted_at'])),
                          SizedBox(height: 12),
                          _richText(
                              'Organization description',
                              _string(app['description'],
                                  fallback: 'Not provided')),
                        ]),
                        SizedBox(height: 16),
                        _section('Trust evidence and public material', [
                          _mediaButtons(app),
                          SizedBox(height: 16),
                          _links(app),
                          SizedBox(height: 16),
                          _evidence(app),
                          SizedBox(height: 16),
                          _documents(app),
                        ]),
                        SizedBox(height: 16),
                        _section('Event plan and standards', [
                          _richText(
                              'Event plan',
                              _string(app['event_plan'],
                                  fallback: 'Not provided')),
                          SizedBox(height: 14),
                          _chips('Planned categories',
                              _strings(app['event_categories'])),
                          SizedBox(height: 14),
                          _chips('Typical audience',
                              _strings(app['typical_audience'])),
                          SizedBox(height: 14),
                          _line(
                              'Khair Organizer Standards',
                              app['guidelines_accepted_at'] == null
                                  ? 'Not accepted'
                                  : 'Accepted · v${_string(app['guidelines_version'])}'),
                        ]),
                        if (!isPending) ...[
                          SizedBox(height: 16),
                          _section('Review outcome', [
                            _line('Status', _display(_string(app['status']))),
                            _line(
                                'Reason code',
                                _display(_string(app['admin_reason_code'],
                                    fallback: 'Not recorded'))),
                            _richText(
                                'Applicant message',
                                _string(app['admin_user_message'],
                                    fallback:
                                        'No applicant message was recorded.')),
                            _richText(
                                'Internal review note',
                                _string(app['internal_admin_note'],
                                    fallback:
                                        'No internal review note was recorded.')),
                            _line('Reviewed at', _date(app['reviewed_at'])),
                          ]),
                        ],
                      ]),
                ),
              ),
            ),
          ),
          if (isPending) _decisionBar(),
        ]),
      ),
    );
  }

  Widget _header(Map<String, dynamic> app) {
    final name = _string(app['public_name'], fallback: 'Unnamed organizer');
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            colors: [Color(0xffffe8ef), Color(0xfffff7f9)]),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            radius: 31,
            backgroundColor: _pink,
            child: Text(initial,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800))),
        SizedBox(width: 15),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff1d1832))),
          SizedBox(height: 4),
          Text(
              '${_display(_string(app['organizer_type']))} · ${_string(app['city'])}, ${_string(app['country_code'])}',
              style: TextStyle(color: Color(0xff716b7d))),
          SizedBox(height: 12),
          _StatusChip(_string(app['status'])),
        ])),
        if ((app['revision_count'] as num? ?? 0) > 0)
          Chip(
              avatar: Icon(Icons.history, size: 17),
              label: Text(context.l10n.revisionCount(
                  (app['revision_count'] as num? ?? 0).toInt())),
          ),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xffeee9ee)),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff1d1832))),
          SizedBox(height: 16),
          ...children,
        ]),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: LayoutBuilder(builder: (context, box) {
          final narrow = box.maxWidth < 510;
          final labelWidget =
              Text(label, style: TextStyle(color: Color(0xff716b7d)));
          final valueWidget = SelectableText(value,
              style: TextStyle(fontWeight: FontWeight.w600));
          return narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  labelWidget,
                  SizedBox(height: 3),
                  valueWidget
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 205, child: labelWidget),
                  Expanded(child: valueWidget)
                ]);
        }),
      );

  Widget _richText(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Color(0xff716b7d))),
        SizedBox(height: 5),
        SelectableText(value,
            style: TextStyle(height: 1.5, fontWeight: FontWeight.w500)),
      ]);

  Widget _chips(String label, List<String> values) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Color(0xff716b7d))),
        SizedBox(height: 8),
        if (values.isEmpty)
          Text(context.l10n.notSpecified)
        else
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map((value) => Chip(label: Text(_display(value))))
                  .toList()),
      ]);

  Widget _mediaButtons(Map<String, dynamic> app) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
          onPressed: app['has_public_logo'] == true
              ? () => _viewMedia('logo', 'Public logo / image')
              : null,
          icon: Icon(Icons.image_outlined),
          label: Text(context.l10n.viewPublicImage),
        ),
        if (app['has_representative_photo'] == true)
          OutlinedButton.icon(
            onPressed: () =>
                _viewMedia('representative-photo', 'Representative photo'),
            icon: Icon(Icons.account_circle_outlined),
            label: Text(context.l10n.viewRepresentativePhoto),
          ),
      ]);

  Widget _links(Map<String, dynamic> app) {
    final links = _mapList(app['links']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.officialPublicLinks,
          style: TextStyle(color: Color(0xff716b7d))),
      SizedBox(height: 6),
      if (links.isEmpty)
        Text(context.l10n.noOfficialLinksProvided)
      else
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                  '${_display(_string(link['platform']))}: ${_string(link['url'])}'),
            )),
    ]);
  }

  Widget _evidence(Map<String, dynamic> app) {
    final evidence = _mapList(app['evidence']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.evidenceEntries,
          style: TextStyle(color: Color(0xff716b7d))),
      SizedBox(height: 6),
      if (evidence.isEmpty)
        Text(context.l10n.noAdditionalEvidenceProvided)
      else
        ...evidence.map((entry) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Color(0xfffaf7f9),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                  '${_display(_string(entry['evidence_type']))}\n${_string(entry['url'])}${_string(entry['note']).isEmpty ? '' : '\n${_string(entry['note'])}'}'),
            )),
    ]);
  }

  Widget _documents(Map<String, dynamic> app) {
    final documents = _mapList(app['verification_files']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.privateVerificationDocuments,
          style: TextStyle(color: Color(0xff716b7d))),
      SizedBox(height: 6),
      if (documents.isEmpty)
        Text(context.l10n.noPrivateDocumentsUploaded)
      else
        ...documents.map((file) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline, color: _pink),
              title: Text(_string(file['original_filename'],
                  fallback: 'Verification document')),
              subtitle: Text(
                  '${_display(_string(file['file_type']))} · ${_fileSize(file['size_bytes'])}'),
              trailing: OutlinedButton.icon(
                onPressed: () => _openDocument(_string(file['id'])),
                icon: Icon(Icons.visibility_outlined, size: 18),
                label: Text(context.l10n.view),
              ),
            )),
    ]);
  }

  Widget _decisionBar() => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Color(0x18000000), blurRadius: 14, offset: Offset(0, -3))
          ]),
          child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _acting ? null : () => _decisionDialog('needs_revision'),
                  icon: Icon(Icons.edit_note_outlined),
                  label: Text(context.l10n.requestChanges),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xffc33a54)),
                  onPressed: _acting ? null : () => _decisionDialog('rejected'),
                  icon: Icon(Icons.close_rounded),
                  label: Text(context.l10n.adminReject),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Color(0xff1f9d63)),
                  onPressed: _acting ? null : () => _decisionDialog('approved'),
                  icon: _acting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(Icons.verified_rounded),
                  label: Text(context.l10n.approveOrganizer),
                ),
              ]),
        ),
      );

  Future<void> _decisionDialog(String decision) async {
    final message = TextEditingController();
    final note = TextEditingController();
    final reason = TextEditingController();
    final label = switch (decision) {
      'approved' => 'Approve organizer',
      'needs_revision' => 'Request changes',
      _ => 'Reject application'
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (decision == 'rejected') ...[
            TextField(
                controller: reason,
                decoration: InputDecoration(
                    labelText: context.l10n.reasonCode,
                    hintText: context.l10n.egIdentityunverified),
                textCapitalization: TextCapitalization.none),
            SizedBox(height: 12),
          ],
          TextField(
            controller: message,
            maxLines: 4,
            decoration: InputDecoration(
                labelText: decision == 'approved'
                    ? 'Optional applicant message'
                    : 'Applicant-facing explanation *',
                hintText: decision == 'needs_revision'
                    ? 'State exactly what needs to be updated.'
                    : 'Explain the decision clearly and respectfully.'),
          ),
          SizedBox(height: 12),
          TextField(
              controller: note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.internalNoteNotShownToApplican)),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.adminCancel)),
          FilledButton(
            onPressed: () {
              if (decision == 'rejected' && reason.text.trim().isEmpty) {
                _snack('A reason code is required to reject an application.');
                return;
              }
              if (decision != 'approved' && message.text.trim().isEmpty) {
                _snack('An applicant-facing explanation is required.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
                backgroundColor:
                    decision == 'approved' ? Color(0xff1f9d63) : _pink),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _acting = true);
    try {
      await _api.decide(
          id: widget.applicationId,
          decision: decision,
          reasonCode: reason.text.trim(),
          userMessage: message.text.trim(),
          internalNote: note.text.trim());
      if (!mounted) return;
      _snack(decision == 'approved'
          ? 'Organizer approved. Access was granted atomically.'
          : 'Decision recorded and applicant notified.');
      await _load();
    } catch (error) {
      if (mounted) {
        _snack(OrganizerApplicationAdminApi.errorMessage(error,
            fallback: 'The review action could not be completed.'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _viewMedia(String kind, String title) async {
    try {
      final url = await _api.mediaUrl(widget.applicationId, kind);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
            child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                title: Text(title),
                trailing: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close))),
            Flexible(
                child: InteractiveViewer(
                    child: Image.network(url.toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                                'The secure image could not be displayed.'))))),
          ]),
        )),
      );
    } catch (error) {
      if (mounted) {
        _snack(OrganizerApplicationAdminApi.errorMessage(error,
            fallback: 'The secure media could not be opened.'));
      }
    }
  }

  Future<void> _openDocument(String fileId) async {
    if (fileId.isEmpty) {
      return;
    }
    try {
      final url = await _api.documentUrl(widget.applicationId, fileId);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open document');
      }
    } catch (error) {
      if (mounted) {
        _snack(OrganizerApplicationAdminApi.errorMessage(error,
            fallback: 'The secure document could not be opened.'));
      }
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  static String _string(dynamic value, {String fallback = ''}) =>
      value is String && value.isNotEmpty ? value : fallback;
  static List<String> _strings(dynamic value) =>
      value is List ? value.whereType<String>().toList() : const [];
  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : const [];
  static String _display(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  static String _yesNo(bool value) => value ? 'Yes' : 'No';
  static String _date(dynamic value) =>
      value is String && DateTime.tryParse(value) != null
          ? DateTime.parse(value).toLocal().toString().split('.').first
          : 'Not available';
  static String _fileSize(dynamic value) {
    final bytes = value is num ? value : num.tryParse('$value') ?? 0;
    return bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(0)} KB'
        : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'approved' => (Color(0xff1f9d63), 'Approved'),
      'needs_revision' => (Color(0xffbd7411), 'Needs changes'),
      'rejected' => (Color(0xffc33a54), 'Rejected'),
      _ => (Color(0xfff43f75), 'Pending review'),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)));
  }
}
