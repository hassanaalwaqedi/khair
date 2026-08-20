import 'package:khair_app/core/locale/l10n_extension.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/utils/image_upload_validator.dart';
import '../../data/organizer_application_api.dart';

/// The server-backed organizer trust gateway. A draft only exists after the
/// API accepts it; uploads and decisions never use a local/mock fallback.
class OrganizerAccessPage extends StatefulWidget {
  const OrganizerAccessPage({super.key});

  @override
  State<OrganizerAccessPage> createState() => _OrganizerAccessPageState();
}

class _OrganizerAccessPageState extends State<OrganizerAccessPage> {
  static const _pink = Color(0xfff43f75);
  static const _ink = Color(0xff1d1832);

  final _api = OrganizerApplicationApi();
  final _publicName = TextEditingController();
  final _representative = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _description = TextEditingController();
  final _eventPlan = TextEditingController();
  final _linkUrl = TextEditingController();
  final _evidenceUrl = TextEditingController();
  final _evidenceNote = TextEditingController();

  final Set<String> _categories = <String>{};
  final Set<String> _audiences = <String>{};
  final List<Map<String, String>> _links = <Map<String, String>>[];
  final List<Map<String, String>> _evidence = <Map<String, String>>[];
  final List<Map<String, dynamic>> _documents = <Map<String, dynamic>>[];
  final ImagePicker _imagePicker = ImagePicker();

  Timer? _autosave;
  Map<String, dynamic>? _application;
  Uint8List? _logoPreview;
  Uint8List? _representativePreview;
  int _step = 0;
  String _organizerType = 'community';
  String _country = 'TR';
  String _linkPlatform = 'website';
  String _evidenceType = 'official_website';
  bool _guidelinesAccepted = false;
  bool _loading = true;
  bool _saving = false;
  bool _submitting = false;
  bool _isTransitioning = false;
  bool _showStatus = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _autosave?.cancel();
    for (final controller in [
      _publicName,
      _representative,
      _email,
      _phone,
      _city,
      _description,
      _eventPlan,
      _linkUrl,
      _evidenceUrl,
      _evidenceNote,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final application = await _api.loadMine();
      if (!mounted) return;
      if (application != null) _hydrate(application);
      if (application != null && application['status'] == 'approved') {
        final org = OrganizerModel(
          id: _string(application['id']),
          userId: _string(application['user_id']),
          name: _string(application['public_name']),
          description: application['description'] as String?,
          status: 'approved',
          createdAt: DateTime.tryParse(_string(application['created_at'])) ??
              DateTime.now(),
          updatedAt: DateTime.tryParse(_string(application['updated_at'])) ??
              DateTime.now(),
        );
        context.read<AuthBloc>().add(OrganizerSessionChanged(org));
      }
      setState(() {
        _application = application;
        _showStatus = application != null &&
            application['status'] != null &&
            application['status'] != 'draft';
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 401) {
        // Session expired — redirect to login preserving the destination.
        context.go('/login?next=${Uri.encodeComponent('/organizer/apply')}');
        return;
      }
      if (kDebugMode) debugPrint('OrganizerAccessPage load error: $e');
      setState(() {
        _loading = false;
        _error = status == 403
            ? context.l10n.organizerAccessDenied
            : context.l10n.organizerApplicationLoadFailed;
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('OrganizerAccessPage unexpected error: $e');
      setState(() {
        _loading = false;
        _error = context.l10n.organizerApplicationLoadFailed;
      });
    }
  }

  void _hydrate(Map<String, dynamic> data) {
    _organizerType = _string(data['organizer_type'], fallback: 'community');
    _publicName.text = _string(data['public_name']);
    _representative.text = _string(data['representative_name']);
    _email.text = _string(data['contact_email']);
    _phone.text = _string(data['phone']);
    _country = _string(data['country_code'], fallback: 'TR');
    _city.text = _string(data['city']);
    _description.text = _string(data['description']);
    _eventPlan.text = _string(data['event_plan']);
    _guidelinesAccepted = data['guidelines_accepted_at'] != null;
    _categories
      ..clear()
      ..addAll(_strings(data['event_categories']));
    _audiences
      ..clear()
      ..addAll(_strings(data['typical_audience']));
    _links
      ..clear()
      ..addAll(_mapList(data['links']));
    _evidence
      ..clear()
      ..addAll(_mapList(data['evidence']));
    _documents
      ..clear()
      ..addAll(_mapDynamicList(data['verification_files']));
  }

  String _string(dynamic value, {String fallback = ''}) =>
      value is String && value.isNotEmpty ? value : fallback;

  List<String> _strings(dynamic value) => value is List
      ? value.whereType<String>().map((item) => item.toLowerCase()).toList()
      : const <String>[];

  List<Map<String, String>> _mapList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => item.map((key, value) =>
              MapEntry(key.toString(), value?.toString() ?? '')))
          .toList()
      : <Map<String, String>>[];

  List<Map<String, dynamic>> _mapDynamicList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : <Map<String, dynamic>>[];

  Map<String, dynamic> get _draft => {
        'organizer_type': _organizerType,
        'public_name': _publicName.text.trim(),
        'representative_name': _representative.text.trim(),
        'contact_email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'country_code': _country,
        'city': _city.text.trim(),
        'description': _description.text.trim(),
        'event_plan': _eventPlan.text.trim(),
        'typical_audience': _audiences.toList(),
        'guidelines_accepted': _guidelinesAccepted,
        'guidelines_version': '2026-08',
        'links': _links,
        'event_categories': _categories.toList(),
        'evidence': _evidence,
      };

  void _queueSave() {
    if (_loading || _showStatus || _submitting) return;
    _autosave?.cancel();
    _autosave = Timer(Duration(milliseconds: 750), () {
      unawaited(_save(quiet: true));
    });
  }

  Future<bool> _save({bool quiet = false}) async {
    if (_saving || _submitting) return true;
    setState(() => _saving = true);
    try {
      final saved = await _api.saveDraft(_draft);
      if (!mounted) return true;
      setState(() {
        _application = saved;
        _error = null;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = _errorText(error, context.l10n.draftSaveFailed);
      // Only show a snackbar — never set _error here, because that would
      // replace the form with the "Try again" error page.
      if (!quiet) _snack(message);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continue() async {
    if (_isTransitioning) return;
    if (_step >= _stepTitles(context).length - 1) return;
    final validation = _validateStep(_step);
    if (validation != null) {
      _snack(validation);
      return;
    }
    setState(() => _isTransitioning = true);
    try {
      if (!await _save()) return;
      if (!mounted) return;
      setState(() => _step += 1);
    } finally {
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  String? _validateStep(int step) {
    if (step == 0) {
      if (_publicName.text.trim().length < 2) {
        return context.l10n.enterPublicOrganizerName;
      }
      if (_representative.text.trim().length < 2) {
        return context.l10n.enterResponsibleRepresentative;
      }
      if (!_email.text.trim().contains('@')) {
        return context.l10n.enterVerifiedAccountEmail;
      }
      if (_city.text.trim().length < 2) {
        return context.l10n.enterCity;
      }
      if (_description.text.trim().length < 50) {
        return context.l10n.organizationDescriptionMinLength;
      }
    }
    if (step == 1) {
      if (_application?['has_public_logo'] != true) {
        return context.l10n.uploadLogoRequired;
      }
      if (_organizerType == 'individual' &&
          _application?['has_representative_photo'] != true) {
        return context.l10n.uploadRepresentativePhotoRequired;
      }
    }
    if (step == 2) {
      if (_eventPlan.text.trim().length < 50) {
        return context.l10n.eventPlanMinLength;
      }
      if (_categories.isEmpty) {
        return context.l10n.chooseEventCategory;
      }
      if (!_guidelinesAccepted) {
        return context.l10n.acceptOrganizerStandards;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isTransitioning || _submitting) return;
    final validation = _validateStep(2);
    if (validation != null) {
      setState(() => _step = 2);
      _snack(validation);
      return;
    }
    setState(() => _isTransitioning = true);
    try {
      if (!await _save()) return;
      setState(() => _submitting = true);
      final status = _application?['status']?.toString();
      final submitted = await _api.submit(resubmit: status == 'needs_revision');
      if (!mounted) return;
      context.read<AuthBloc>().add(CheckAuthStatus());
      setState(() {
        _application = submitted;
        _showStatus = true;
      });
    } catch (error) {
      if (mounted) {
        _snack(_errorText(error, context.l10n.organizerApplicationSubmitFailed));
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _isTransitioning = false;
        });
      }
    }
  }

  Future<void> _pickImage({required bool representativePhoto}) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    try {
      final validation = validateImageUpload(
        filename: file.name,
        byteLength: await file.length(),
      );
      if (validation != null) {
        _snack(validation);
        return;
      }
      final bytes = await file.readAsBytes();
      final updated = await _api.uploadImage(
        bytes: bytes,
        filename: file.name,
        representativePhoto: representativePhoto,
      );
      if (!mounted) return;
      setState(() {
        _application = updated;
        if (representativePhoto) {
          _representativePreview = bytes;
        } else {
          _logoPreview = bytes;
        }
      });
      _snack(context.l10n.imageUploadComplete);
    } catch (error) {
      if (mounted) _snack(_errorText(error, context.l10n.imageUploadFailed));
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    final picked = result?.files.singleOrNull;
    if (picked == null || picked.bytes == null) return;
    final type = await _chooseDocumentType();
    if (type == null) return;
    try {
      final file = await _api.uploadDocument(
        bytes: picked.bytes!,
        filename: picked.name,
        fileType: type,
      );
      if (!mounted) return;
      setState(() => _documents.add(file));
      _snack(context.l10n.documentUploadComplete);
    } catch (error) {
      if (mounted) _snack(_errorText(error, context.l10n.documentUploadFailed));
    }
  }

  Future<String?> _chooseDocumentType() => showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(context.l10n.whatDoesThisDocumentVerify,
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final item in {
              'registration': context.l10n.organizationRegistration,
              'charity_registration': context.l10n.charityRegistration,
              'community_document': context.l10n.communityDocument,
              'school_company_document': context.l10n.schoolCompanyDocument,
              'other': context.l10n.otherSupportingDocument,
            }.entries)
              ListTile(
                leading: Icon(Icons.description_outlined),
                title: Text(item.value),
                onTap: () => Navigator.pop(context, item.key),
              ),
          ]),
        ),
      );

  void _addLink() {
    final url = _linkUrl.text.trim();
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
      _snack(context.l10n.addHttpsLink);
      return;
    }
    setState(() {
      _links.add({'platform': _linkPlatform, 'url': url});
      _linkUrl.clear();
    });
    _queueSave();
  }

  void _addEvidence() {
    final url = _evidenceUrl.text.trim();
    final note = _evidenceNote.text.trim();
    if (url.isEmpty && note.isEmpty) {
      _snack(context.l10n.addEvidenceUrlOrNote);
      return;
    }
    final parsed = Uri.tryParse(url);
    if (url.isNotEmpty &&
        (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty)) {
      _snack(context.l10n.addHttpsEvidenceUrl);
      return;
    }
    setState(() {
      _evidence.add({'evidence_type': _evidenceType, 'url': url, 'note': note});
      _evidenceUrl.clear();
      _evidenceNote.clear();
    });
    _queueSave();
  }

  String _errorText(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
    }
    return fallback;
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _application == null) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: Icon(Icons.refresh),
            label: Text(context.l10n.tryAgain),
          ),
        ),
      );
    }
    if (_showStatus) return _statusPage();

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step > 0) {
          setState(() => _step -= 1);
        }
      },
      child: Scaffold(
        backgroundColor: Color(0xfffdfbfc),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.go('/'),
            icon: Icon(Icons.close_rounded),
            tooltip: context.l10n.closeOrganizerApplication,
          ),
          title: Text(context.l10n.becomeAnOrganizer),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(_saving
                    ? context.l10n.savingDraft
                    : context.l10n.draftSavedSecurely,
                    style:
                        TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 980),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 116),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _progress(),
                      SizedBox(height: 30),
                      Text(_stepTitles(context)[_step],
                          style: TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                      SizedBox(height: 8),
                      Text(_stepDescriptions(context)[_step],
                          style: TextStyle(
                              fontSize: 16, color: Color(0xff716b7d))),
                      SizedBox(height: 24),
                      _stepBody(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 14,
                  offset: Offset(0, -3))
            ]),
            child: Row(children: [
              if (_step > 0)
                TextButton.icon(
                  onPressed:
                      _submitting ? null : () => setState(() => _step -= 1),
                  icon: Icon(Icons.arrow_back),
                  label: Text(context.l10n.createEventBack),
                ),
              Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _pink, minimumSize: Size(172, 52)),
                onPressed:
                    _submitting ? null : (_step == 3 ? _submit : _continue),
                icon: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(_step == 3
                        ? Icons.verified_rounded
                        : Icons.arrow_forward_rounded),
              label: Text(_step == 3
                  ? context.l10n.submitForReview
                  : context.l10n.registrationContinue),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  List<String> _stepTitles(BuildContext context) => [
        context.l10n.tellUsAboutYou,
        context.l10n.buildTrust,
        context.l10n.yourEvents,
        context.l10n.reviewYourApplication,
      ];

  List<String> _stepDescriptions(BuildContext context) => [
        context.l10n.tellUsAboutYouDescription,
        context.l10n.buildTrustDescription,
        context.l10n.yourEventsDescription,
        context.l10n.reviewYourApplicationDescription,
      ];

  Widget _progress() => Semantics(
        label: context.l10n.organizerApplicationStep(_step + 1),
        child: Row(
          children: List.generate(4, (index) {
            final active = index <= _step;
            return Expanded(
              child: Row(children: [
                Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? _pink : Color(0xfff0edf1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(context.l10n.stepNumber(index + 1),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              active ? Colors.white : Color(0xff746f7d))),
                ),
                if (index < 3)
                  Expanded(
                      child: Container(
                          height: 3,
                          color:
                              index < _step ? _pink : Color(0xffeeeaf0))),
              ]),
            );
          }),
        ),
      );

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _aboutStep();
      case 1:
        return _trustStep();
      case 2:
        return _eventsStep();
      default:
        return _reviewStep();
    }
  }

  Widget _aboutStep() => _panel(
        children: [
          _FieldLabel(context.l10n.organizerType),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: {
              'individual': context.l10n.individual,
              'community': context.l10n.catCommunity,
              'mosque': context.l10n.registrationOrgTypeMosque,
              'charity': context.l10n.registrationOrgTypeCharity,
              'company': context.l10n.company,
              'school': context.l10n.school,
              'other': context.l10n.other,
            }
                .entries
                .map((entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: _organizerType == entry.key,
                      selectedColor: _pink.withValues(alpha: .14),
                      onSelected: (_) {
                        setState(() => _organizerType = entry.key);
                        _queueSave();
                      },
                    ))
                .toList(),
          ),
          SizedBox(height: 24),
          _field(_publicName, context.l10n.publicOrganizerName),
          SizedBox(height: 14),
          _field(_representative, context.l10n.responsibleRepresentative),
          SizedBox(height: 14),
          _field(_email, context.l10n.verifiedAccountEmail,
              keyboardType: TextInputType.emailAddress),
          SizedBox(height: 14),
          _field(_phone, context.l10n.phoneInternationalOptional,
              keyboardType: TextInputType.phone),
          SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: _country,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: InputDecoration(
                    labelText: context.l10n.countryCode, hintText: context.l10n.tr),
                onChanged: (value) {
                  setState(() => _country = value.trim().toUpperCase());
                  _queueSave();
                },
              ),
            ),
            SizedBox(width: 14),
            Expanded(child: _field(_city, context.l10n.city)),
          ]),
          SizedBox(height: 14),
          _field(_description, context.l10n.aboutYourOrganization,
              hint:
                  context.l10n.aboutYourOrganizationHint,
              maxLines: 5),
        ],
      );

  Widget _trustStep() => _panel(children: [
        _uploadCard(
          title: context.l10n.publicLogoOrProfileImage,
          subtitle: context.l10n.jpgPngOrWebpUpTo5MbPrivateUnti,
          bytes: _logoPreview,
          isUploaded: _application?['has_public_logo'] == true,
          onPressed: () => _pickImage(representativePhoto: false),
        ),
        if (_organizerType == 'individual') ...[
          SizedBox(height: 16),
          _uploadCard(
            title: context.l10n.publicRepresentativePhoto,
            subtitle: context.l10n.requiredForIndividualOrganizer,
            bytes: _representativePreview,
            isUploaded: _application?['has_representative_photo'] == true,
            onPressed: () => _pickImage(representativePhoto: true),
          ),
        ],
        SizedBox(height: 26),
        Text(context.l10n.officialLinks,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text(context.l10n.optionalButUsefulForFasterReview),
        SizedBox(height: 12),
        _addLinkRow(),
        _linkChips(),
        Divider(height: 40),
        Text(context.l10n.verificationEvidence,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text(context.l10n.documentsAreEncryptedInPrivate),
        SizedBox(height: 12),
        _addEvidenceRow(),
        _evidenceChips(),
        SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDocument,
          icon: Icon(Icons.upload_file_outlined),
          label: Text(context.l10n.uploadVerificationDocument),
        ),
        if (_documents.isNotEmpty) ...[
          SizedBox(height: 10),
          ..._documents.map((file) => Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.verified_user_outlined, color: _pink),
                  title: Text(_string(file['original_filename'],
                      fallback: context.l10n.secureDocument)),
                  subtitle: Text(context.l10n.privateDocumentType(
                      file['file_type']?.toString() ?? '')),
                  trailing: Icon(Icons.lock_outline, size: 18),
                ),
              )),
        ],
      ]);

  Widget _eventsStep() => _panel(children: [
        _field(_eventPlan, context.l10n.whatEventsWillYouHost,
            hint:
                context.l10n.eventPlanDescriptionHint,
            maxLines: 5),
        SizedBox(height: 22),
        Text(context.l10n.plannedEventCategories,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        _selectionChips(
          {
            'community': context.l10n.catCommunity,
            'charity': context.l10n.catCharity,
            'lecture': context.l10n.lecture,
            'workshop': context.l10n.workshop,
            'conference': context.l10n.conference,
            'family': context.l10n.categoryFamily,
            'youth': context.l10n.categoryYouth,
            'technology': context.l10n.technology,
            'online': context.l10n.online,
            'education': context.l10n.education,
            'social_gathering': context.l10n.socialGathering,
            'other': context.l10n.other,
          },
          _categories,
        ),
        SizedBox(height: 22),
        Text(context.l10n.typicalAudience,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        _selectionChips({
          'everyone': context.l10n.everyone,
          'families': context.l10n.families,
          'youth': context.l10n.categoryYouth,
          'students': context.l10n.students,
          'professionals': context.l10n.professionals,
          'men': context.l10n.men,
          'women': context.l10n.women,
          'other': context.l10n.other,
        }, _audiences),
        SizedBox(height: 26),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: _guidelinesAccepted,
            contentPadding: EdgeInsets.zero,
            activeColor: _pink,
            title: Text(context.l10n.iAcceptTheKhairOrganizerStanda,
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(context.l10n.iWillKeepEventsSafeRespectfulA),
            onChanged: (value) {
              setState(() => _guidelinesAccepted = value ?? false);
              _queueSave();
            },
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _showGuidelines,
            icon: Icon(Icons.menu_book_outlined),
            label: Text(context.l10n.readOrganizerStandardsV202608),
          ),
        ),
      ]);

  Future<void> _showGuidelines() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.khairOrganizerStandards,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(context.l10n.version202608,
                        style: TextStyle(color: Color(0xff716b7d))),
                    SizedBox(height: 20),
                    for (final rule in [
                      context.l10n.organizerRuleAccurate,
                      context.l10n.organizerRuleSafe,
                      context.l10n.organizerRuleRights,
                      context.l10n.organizerRulePrivacy,
                      context.l10n.organizerRuleLaw,
                      context.l10n.organizerRuleReview,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: _pink, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                  child: Text(rule,
                                      style: TextStyle(height: 1.45))),
                            ]),
                      ),
                    SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _pink),
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.iUnderstand),
                    ),
                  ]),
            ),
          ),
        ),
      );

  Widget _reviewStep() => _panel(children: [
        _reviewGroup(context.l10n.publicProfile, [
          _reviewLine(context.l10n.type, _localizedDisplay(context, _organizerType)),
          _reviewLine(context.l10n.name, _publicName.text.trim()),
          _reviewLine(context.l10n.representative, _representative.text.trim()),
          _reviewLine(context.l10n.contactEmail, _email.text.trim()),
          _reviewLine(context.l10n.location,
              '${_city.text.trim()}, $_country'),
        ]),
        _reviewGroup(context.l10n.trustMaterial, [
          _reviewLine(
              context.l10n.publicImage,
              _application?['has_public_logo'] == true
                  ? context.l10n.uploaded
                  : context.l10n.missing),
          _reviewLine(context.l10n.officialLinks,
              context.l10n.itemsCount(_links.length, context.l10n.added)),
          _reviewLine(context.l10n.evidence,
              context.l10n.itemsCount(_evidence.length, context.l10n.added)),
          _reviewLine(context.l10n.privateDocuments,
              context.l10n.itemsCount(_documents.length, context.l10n.uploaded)),
        ]),
        _reviewGroup(context.l10n.events, [
          _reviewLine(context.l10n.categories,
              _categories.map((item) => _localizedDisplay(context, item)).join(', ')),
          _reviewLine(
              context.l10n.audience,
              _audiences.isEmpty
                  ? context.l10n.notSpecified
                  : _audiences
                      .map((item) => _localizedDisplay(context, item))
                      .join(', ')),
          _reviewLine(
              context.l10n.standards,
              _guidelinesAccepted
                  ? context.l10n.accepted
                  : context.l10n.notAccepted),
        ]),
        SizedBox(height: 12),
        _Notice(
          icon: Icons.admin_panel_settings_outlined,
          text: context.l10n.reviewNotice,
        ),
      ]);

  Widget _statusPage() {
    final status = _string(_application?['status']);
    final isApproved = status == 'approved';
    final needsRevision = status == 'needs_revision';
    final rejected = status == 'rejected';
    final suspended = status == 'suspended';
    final isDraft = status == 'draft';
    
    final title = isApproved
        ? context.l10n.organizerApproved
        : needsRevision
            ? context.l10n.applicationNeedsChanges
            : rejected
                ? context.l10n.applicationNotApproved
                : suspended
                    ? context.l10n.organizerAccountSuspended
                    : isDraft
                        ? context.l10n.applicationIncomplete
                        : context.l10n.applicationUnderReview;
    final message = isApproved
        ? context.l10n.organizerToolsAvailable
        : needsRevision
            ? _string(_application?['admin_user_message'],
                fallback: context.l10n.reviewFeedbackAndResubmit)
            : rejected
                ? _string(_application?['admin_user_message'],
                    fallback: context.l10n.applicationClosedContactSupport)
                : suspended
                    ? _string(_application?['admin_user_message'],
                        fallback: context.l10n.contactSupportForMoreInformation)
                    : isDraft
                        ? context.l10n.completeApplicationToOrganize
                        : context.l10n.applicationWithReviewTeam;
    final icon = isApproved
        ? Icons.verified_rounded
        : needsRevision
            ? Icons.edit_note_outlined
            : rejected
                ? Icons.cancel_outlined
                : suspended
                    ? Icons.block_flipped
                    : isDraft
                        ? Icons.edit_document
                        : Icons.hourglass_top_rounded;
    return Scaffold(
      backgroundColor: Color(0xfffdfbfc),
      appBar: AppBar(
          leading: IconButton(
              onPressed: () => context.go('/'), icon: Icon(Icons.close))),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 580),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                      radius: 34,
                      backgroundColor: _pink.withValues(alpha: .12),
                      child: Icon(icon, size: 38, color: _pink)),
                  SizedBox(height: 20),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          height: 1.5, color: Color(0xff716b7d))),
                  if ((needsRevision || rejected) &&
                      _string(_application?['admin_reason_code'])
                          .isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                        context.l10n.reasonLabel,
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _localizedDisplay(context,
                            _string(_application?['admin_reason_code'])),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: isApproved
                        ? () {
                            if (_application != null) {
                              final org = OrganizerModel(
                                id: _string(_application!['id']),
                                userId: _string(_application!['user_id']),
                                name: _string(_application!['public_name']),
                                description:
                                    _application!['description'] as String?,
                                status: 'approved',
                                createdAt: DateTime.tryParse(
                                        _string(_application!['created_at'])) ??
                                    DateTime.now(),
                                updatedAt: DateTime.tryParse(
                                        _string(_application!['updated_at'])) ??
                                    DateTime.now(),
                              );
                              context
                                  .read<AuthBloc>()
                                  .add(OrganizerSessionChanged(org));
                            }
                            context.go('/organizer');
                          }
                        : needsRevision
                            ? () => setState(() {
                                  _showStatus = false;
                                  _step = 0;
                                })
                            : rejected
                                ? () => context.go('/')
                                : _load,
                    icon: Icon(isApproved
                        ? Icons.dashboard_outlined
                        : needsRevision || rejected
                            ? Icons.edit_outlined
                            : Icons.refresh),
                    label: Text(isApproved
                        ? context.l10n.openOrganizerHub
                        : needsRevision
                            ? context.l10n.updateApplication
                            : rejected
                                ? context.l10n.backToDiscover
                                : context.l10n.refreshStatus),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Color(0xffeee9ee))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _field(TextEditingController controller, String label,
          {String? hint, int maxLines = 1, TextInputType? keyboardType}) =>
        TextField(
        controller: controller,
        onChanged: (_) => _queueSave(),
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: (keyboardType == TextInputType.phone ||
                        keyboardType == TextInputType.emailAddress ||
                        keyboardType == TextInputType.url)
                       ? TextDirection.ltr : null,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            alignLabelWithHint: maxLines > 1,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      );

  Widget _uploadCard(
          {required String title,
          required String subtitle,
          required Uint8List? bytes,
          required bool isUploaded,
          required VoidCallback onPressed}) =>
      InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Color(0xfffff4f7),
              border: Border.all(color: _pink.withValues(alpha: .45)),
              borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 96,
                width: 96,
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 192,
                        cacheHeight: 192,
                      )
                    : Container(
                        color: Colors.white,
                        child: Icon(
                            isUploaded
                                ? Icons.check_circle_rounded
                                : Icons.add_photo_alternate_outlined,
                            color: _pink,
                            size: 36)),
              ),
            ),
            SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 5),
                  Text(
                      isUploaded
                          ? context.l10n.uploadedSecurelyTapToReplace
                          : subtitle,
                      style: TextStyle(color: Color(0xff716b7d))),
                  SizedBox(height: 12),
                  Text(isUploaded
                      ? context.l10n.replaceImage
                      : context.l10n.chooseImage,
                      style: TextStyle(
                          color: _pink, fontWeight: FontWeight.w800)),
                ])),
          ]),
        ),
      );

  Widget _addLinkRow() => Row(children: [
        DropdownButton<String>(
            value: _linkPlatform,
            items: const [
              'website',
              'instagram',
              'facebook',
              'linkedin',
              'other'
            ]
                .map((item) =>
                    DropdownMenuItem(
                        value: item,
                        child: Text(_localizedDisplay(context, item))))
                .toList(),
            onChanged: (value) => setState(() => _linkPlatform = value!)),
        SizedBox(width: 12),
        Expanded(child: _field(_linkUrl, context.l10n.httpsLinkHint)),
        SizedBox(width: 8),
        IconButton(
            onPressed: _addLink,
            color: _pink,
            icon: Icon(Icons.add_circle)),
      ]);

  Widget _addEvidenceRow() => Column(children: [
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
                  initialValue: _evidenceType,
        decoration: InputDecoration(labelText: context.l10n.evidenceType),
                  items: const [
                    'official_website',
                    'verified_social',
                    'registration',
                    'charity_registration',
                    'community_document',
                    'school_company_document',
                    'other'
                  ]
                      .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(_localizedDisplay(context, item))))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _evidenceType = value!))),
          SizedBox(width: 12),
          Expanded(
              child: _field(_evidenceUrl, context.l10n.evidenceUrlOptional)),
        ]),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_evidenceNote, context.l10n.shortNoteOptional)),
          SizedBox(width: 8),
          IconButton(
              onPressed: _addEvidence,
              color: _pink,
              icon: Icon(Icons.add_circle)),
        ]),
      ]);

  Widget _linkChips() => _removableChips(
          _links
              .map((item) =>
                  '${_localizedDisplay(context, item['platform'] ?? '')}: ${item['url'] ?? ''}')
              .toList(), (index) {
        setState(() => _links.removeAt(index));
        _queueSave();
      });

  Widget _evidenceChips() => _removableChips(
          _evidence
              .map((item) =>
                  '${_localizedDisplay(context, item['evidence_type'] ?? '')}${(item['url'] ?? '').isNotEmpty ? ': ${item['url']}' : ''}')
              .toList(), (index) {
        setState(() => _evidence.removeAt(index));
        _queueSave();
      });

  Widget _removableChips(List<String> labels, ValueChanged<int> remove) =>
      labels.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                      labels.length,
                      (index) => InputChip(
                          label: Text(labels[index],
                              overflow: TextOverflow.ellipsis),
                          onDeleted: () => remove(index)))),
            );

  Widget _selectionChips(Map<String, String> options, Set<String> selected) =>
      Wrap(
        spacing: 9,
        runSpacing: 9,
        children: options.entries
            .map((item) => FilterChip(
                  label: Text(item.value),
                  selected: selected.contains(item.key),
                  selectedColor: _pink.withValues(alpha: .14),
                  checkmarkColor: _pink,
                  onSelected: (value) {
                    setState(() => value
                        ? selected.add(item.key)
                        : selected.remove(item.key));
                    _queueSave();
                  },
                ))
            .toList(),
      );

  Widget _reviewGroup(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _reviewLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 145,
              child: Text(label,
                  style: TextStyle(color: Color(0xff716b7d)))),
          Expanded(
              child: Text(value.isEmpty ? context.l10n.notProvided : value,
                  style: TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  String _localizedDisplay(BuildContext context, String value) {
    final l10n = context.l10n;
    switch (value) {
      case 'individual':
        return l10n.individual;
      case 'community':
        return l10n.catCommunity;
      case 'mosque':
        return l10n.registrationOrgTypeMosque;
      case 'charity':
        return l10n.registrationOrgTypeCharity;
      case 'company':
        return l10n.company;
      case 'school':
        return l10n.school;
      case 'other':
        return l10n.other;
      case 'website':
        return l10n.website;
      case 'instagram':
        return l10n.instagram;
      case 'facebook':
        return l10n.facebook;
      case 'linkedin':
        return l10n.linkedin;
      case 'official_website':
        return l10n.officialWebsite;
      case 'verified_social':
        return l10n.verifiedSocial;
      case 'registration':
        return l10n.organizationRegistration;
      case 'charity_registration':
        return l10n.charityRegistration;
      case 'community_document':
        return l10n.communityDocument;
      case 'school_company_document':
        return l10n.schoolCompanyDocument;
      case 'lecture':
        return l10n.lecture;
      case 'workshop':
        return l10n.workshop;
      case 'conference':
        return l10n.conference;
      case 'family':
        return l10n.categoryFamily;
      case 'youth':
        return l10n.categoryYouth;
      case 'technology':
        return l10n.technology;
      case 'online':
        return l10n.online;
      case 'education':
        return l10n.education;
      case 'social_gathering':
        return l10n.socialGathering;
      case 'everyone':
        return l10n.everyone;
      case 'families':
        return l10n.families;
      case 'students':
        return l10n.students;
      case 'professionals':
        return l10n.professionals;
      case 'men':
        return l10n.men;
      case 'women':
        return l10n.women;
      default:
        return _display(value);
    }
  }

  String _display(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Color(0xfffff4f7),
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Color(0xfff43f75)),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(height: 1.45))),
        ]),
      );
}
