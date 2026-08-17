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
            ? 'Your account does not have access to the organizer application.'
            : 'We could not load your organizer application. Try again.';
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('OrganizerAccessPage unexpected error: $e');
      setState(() {
        _loading = false;
        _error = 'We could not load your organizer application. Try again.';
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
    _autosave = Timer(const Duration(milliseconds: 750), () {
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
      final message = _errorText(error, 'We could not save your draft.');
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
    if (_step >= _stepTitles.length - 1) return;
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
        return 'Enter your public organizer name.';
      }
      if (_representative.text.trim().length < 2) {
        return 'Enter the responsible representative.';
      }
      if (!_email.text.trim().contains('@')) {
        return 'Enter your verified account email.';
      }
      if (_city.text.trim().length < 2) {
        return 'Enter your city.';
      }
      if (_description.text.trim().length < 50) {
        return 'Add at least 50 characters about your organization.';
      }
    }
    if (step == 1) {
      if (_application?['has_public_logo'] != true) {
        return 'Upload a public logo or profile image.';
      }
      if (_organizerType == 'individual' &&
          _application?['has_representative_photo'] != true) {
        return 'Upload your public profile photo.';
      }
    }
    if (step == 2) {
      if (_eventPlan.text.trim().length < 50) {
        return 'Describe your event plan in at least 50 characters.';
      }
      if (_categories.isEmpty) {
        return 'Choose at least one planned event category.';
      }
      if (!_guidelinesAccepted) {
        return 'Accept the Khair Organizer Standards to continue.';
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
        _snack(_errorText(error, 'We could not submit your application.'));
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
      _snack('Upload complete. Your image remains private until approval.');
    } catch (error) {
      if (mounted) _snack(_errorText(error, 'Image upload failed.'));
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
      _snack('Verification document uploaded securely.');
    } catch (error) {
      if (mounted) _snack(_errorText(error, 'Document upload failed.'));
    }
  }

  Future<String?> _chooseDocumentType() => showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
              title: Text('What does this document verify?',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final item in const {
              'registration': 'Organization registration',
              'charity_registration': 'Charity registration',
              'community_document': 'Community document',
              'school_company_document': 'School or company document',
              'other': 'Other supporting document',
            }.entries)
              ListTile(
                leading: const Icon(Icons.description_outlined),
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
      _snack('Add a complete https:// link.');
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
      _snack('Add a URL or a short note for this evidence.');
      return;
    }
    final parsed = Uri.tryParse(url);
    if (url.isNotEmpty &&
        (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty)) {
      _snack('Add a complete https:// evidence URL.');
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _application == null) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
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
        backgroundColor: const Color(0xfffdfbfc),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close organizer application',
          ),
          title: const Text('Become an organizer'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(_saving ? 'Saving…' : 'Draft saved securely',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 116),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _progress(),
                      const SizedBox(height: 30),
                      Text(_stepTitles[_step],
                          style: const TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                      const SizedBox(height: 8),
                      Text(_stepDescriptions[_step],
                          style: const TextStyle(
                              fontSize: 16, color: Color(0xff716b7d))),
                      const SizedBox(height: 24),
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
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [
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
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _pink, minimumSize: const Size(172, 52)),
                onPressed:
                    _submitting ? null : (_step == 3 ? _submit : _continue),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(_step == 3
                        ? Icons.verified_rounded
                        : Icons.arrow_forward_rounded),
                label: Text(_step == 3 ? 'Submit for review' : 'Continue'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static const _stepTitles = [
    'Tell us about you',
    'Build trust',
    'Your events',
    'Review your application',
  ];
  static const _stepDescriptions = [
    'Set up the public identity people will see on Khair.',
    'Add the image and optional evidence that help us verify your application.',
    'Show the kinds of safe, meaningful events you plan to host.',
    'Confirm the details before sending your application to the Khair review team.',
  ];

  Widget _progress() => Semantics(
        label: 'Organizer application step ${_step + 1} of 4',
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
                    color: active ? _pink : const Color(0xfff0edf1),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              active ? Colors.white : const Color(0xff746f7d))),
                ),
                if (index < 3)
                  Expanded(
                      child: Container(
                          height: 3,
                          color:
                              index < _step ? _pink : const Color(0xffeeeaf0))),
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
          const _FieldLabel('Organizer type'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: {
              'individual': 'Individual',
              'community': 'Community',
              'mosque': 'Mosque',
              'charity': 'Charity',
              'company': 'Company',
              'school': 'School',
              'other': 'Other',
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
          const SizedBox(height: 24),
          _field(_publicName, 'Public organizer name'),
          const SizedBox(height: 14),
          _field(_representative, 'Responsible representative'),
          const SizedBox(height: 14),
          _field(_email, 'Verified account email',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _field(_phone, 'Phone (optional, international format)',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: _country,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                    labelText: 'Country code', hintText: 'TR'),
                onChanged: (value) {
                  setState(() => _country = value.trim().toUpperCase());
                  _queueSave();
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _field(_city, 'City')),
          ]),
          const SizedBox(height: 14),
          _field(_description, 'About your organization',
              hint:
                  'Who are you, what is your purpose, and why should the Khair community trust your events?',
              maxLines: 5),
        ],
      );

  Widget _trustStep() => _panel(children: [
        _uploadCard(
          title: 'Public logo or profile image',
          subtitle: 'JPG, PNG, or WebP · up to 5 MB. Private until approved.',
          bytes: _logoPreview,
          isUploaded: _application?['has_public_logo'] == true,
          onPressed: () => _pickImage(representativePhoto: false),
        ),
        if (_organizerType == 'individual') ...[
          const SizedBox(height: 16),
          _uploadCard(
            title: 'Public representative photo',
            subtitle:
                'Required for individual organizers. Visible only after approval.',
            bytes: _representativePreview,
            isUploaded: _application?['has_representative_photo'] == true,
            onPressed: () => _pickImage(representativePhoto: true),
          ),
        ],
        const SizedBox(height: 26),
        const Text('Official links',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
            'Optional, but useful for a faster review. Only add official public links.'),
        const SizedBox(height: 12),
        _addLinkRow(),
        _linkChips(),
        const Divider(height: 40),
        const Text('Verification evidence',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
            'Documents are encrypted in private storage and are accessible only to authorized Khair reviewers.'),
        const SizedBox(height: 12),
        _addEvidenceRow(),
        _evidenceChips(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDocument,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Upload verification document'),
        ),
        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._documents.map((file) => Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.verified_user_outlined, color: _pink),
                  title: Text(_string(file['original_filename'],
                      fallback: 'Secure document')),
                  subtitle: Text('${_string(file['file_type'])} · private'),
                  trailing: const Icon(Icons.lock_outline, size: 18),
                ),
              )),
        ],
      ]);

  Widget _eventsStep() => _panel(children: [
        _field(_eventPlan, 'What events will you host?',
            hint:
                'Describe your event ideas, frequency, safety plan, and the value for your community.',
            maxLines: 5),
        const SizedBox(height: 22),
        const Text('Planned event categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _selectionChips(
          const {
            'community': 'Community',
            'charity': 'Charity',
            'lecture': 'Lecture',
            'workshop': 'Workshop',
            'conference': 'Conference',
            'family': 'Family',
            'youth': 'Youth',
            'technology': 'Technology',
            'online': 'Online',
            'education': 'Education',
            'social_gathering': 'Social gathering',
            'other': 'Other',
          },
          _categories,
        ),
        const SizedBox(height: 22),
        const Text('Typical audience',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _selectionChips(const {
          'everyone': 'Everyone',
          'families': 'Families',
          'youth': 'Youth',
          'students': 'Students',
          'professionals': 'Professionals',
          'men': 'Men',
          'women': 'Women',
          'other': 'Other',
        }, _audiences),
        const SizedBox(height: 26),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: _guidelinesAccepted,
            contentPadding: EdgeInsets.zero,
            activeColor: _pink,
            title: const Text('I accept the Khair Organizer Standards',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'I will keep events safe, respectful, accurate, and inclusive. Version 2026-08.'),
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
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Read Organizer Standards · v2026-08'),
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
                    const Text('Khair Organizer Standards',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Version 2026-08',
                        style: TextStyle(color: Color(0xff716b7d))),
                    const SizedBox(height: 20),
                    for (final rule in const [
                      'Publish accurate, complete event information and update attendees promptly when plans change.',
                      'Create safe, respectful gatherings. Do not discriminate, harass, mislead, or facilitate harmful activity.',
                      'Use only images, names, documents, and links you are entitled to share.',
                      'Protect attendee privacy and never use Khair data for unsolicited contact or unrelated marketing.',
                      'Follow local law, venue requirements, and Khair content and community policies.',
                      'Cooperate with review requests and keep your organizer profile and verification material current.',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: _pink, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(rule,
                                      style: const TextStyle(height: 1.45))),
                            ]),
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _pink),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('I understand'),
                    ),
                  ]),
            ),
          ),
        ),
      );

  Widget _reviewStep() => _panel(children: [
        _reviewGroup('Public profile', [
          _reviewLine('Type', _organizerType),
          _reviewLine('Name', _publicName.text.trim()),
          _reviewLine('Representative', _representative.text.trim()),
          _reviewLine('Contact email', _email.text.trim()),
          _reviewLine('Location', '${_city.text.trim()}, $_country'),
        ]),
        _reviewGroup('Trust material', [
          _reviewLine(
              'Public image',
              _application?['has_public_logo'] == true
                  ? 'Uploaded'
                  : 'Missing'),
          _reviewLine('Official links', '${_links.length} added'),
          _reviewLine('Evidence', '${_evidence.length} added'),
          _reviewLine('Private documents', '${_documents.length} uploaded'),
        ]),
        _reviewGroup('Events', [
          _reviewLine('Categories', _categories.map(_display).join(', ')),
          _reviewLine(
              'Audience',
              _audiences.isEmpty
                  ? 'Not specified'
                  : _audiences.map(_display).join(', ')),
          _reviewLine(
              'Standards', _guidelinesAccepted ? 'Accepted' : 'Not accepted'),
        ]),
        const SizedBox(height: 12),
        const _Notice(
          icon: Icons.admin_panel_settings_outlined,
          text:
              'A Khair admin will review this application. You will receive an in-app notification, push notification when available, and an email after a decision.',
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
        ? 'You are approved to organize'
        : needsRevision
            ? 'Your application needs changes'
            : rejected
                ? 'Your application was not approved'
                : suspended
                    ? 'Your organizer account is suspended'
                    : isDraft
                        ? 'Your application is incomplete'
                        : 'Your application is under review';
    final message = isApproved
        ? 'Organizer tools are now available on your account.'
        : needsRevision
            ? _string(_application?['admin_user_message'],
                fallback:
                    'Review the feedback, update your draft, and submit again when ready.')
            : rejected
                ? _string(_application?['admin_user_message'],
                    fallback:
                        'This application is closed. Contact Khair support if you need help with the decision.')
                : suspended
                    ? _string(_application?['admin_user_message'],
                        fallback: 'Contact Khair support for more information.')
                    : isDraft
                        ? 'Complete and submit your application to start organizing events.'
                        : 'Your details, evidence, and event plan are securely with the Khair review team.';
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
      backgroundColor: const Color(0xfffdfbfc),
      appBar: AppBar(
          leading: IconButton(
              onPressed: () => context.go('/'), icon: const Icon(Icons.close))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
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
                  const SizedBox(height: 20),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  const SizedBox(height: 10),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          height: 1.5, color: Color(0xff716b7d))),
                  if ((needsRevision || rejected) &&
                      _string(_application?['admin_reason_code'])
                          .isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                        'Reason: ${_display(_string(_application?['admin_reason_code']))}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 24),
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
                        ? 'Open organizer hub'
                        : needsRevision
                            ? 'Update application'
                            : rejected
                                ? 'Back to discover'
                                : 'Refresh status'),
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
            border: Border.all(color: const Color(0xffeee9ee))),
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
          constraints: const BoxConstraints(minHeight: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: const Color(0xfffff4f7),
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
            const SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                      isUploaded
                          ? 'Uploaded securely. Tap to replace.'
                          : subtitle,
                      style: const TextStyle(color: Color(0xff716b7d))),
                  const SizedBox(height: 12),
                  Text(isUploaded ? 'Replace image' : 'Choose image',
                      style: const TextStyle(
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
                    DropdownMenuItem(value: item, child: Text(_label(item))))
                .toList(),
            onChanged: (value) => setState(() => _linkPlatform = value!)),
        const SizedBox(width: 12),
        Expanded(child: _field(_linkUrl, 'https://…')),
        const SizedBox(width: 8),
        IconButton(
            onPressed: _addLink,
            color: _pink,
            icon: const Icon(Icons.add_circle)),
      ]);

  Widget _addEvidenceRow() => Column(children: [
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
                  initialValue: _evidenceType,
                  decoration: const InputDecoration(labelText: 'Evidence type'),
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
                          value: item, child: Text(_display(item))))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _evidenceType = value!))),
          const SizedBox(width: 12),
          Expanded(child: _field(_evidenceUrl, 'Evidence URL (optional)')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_evidenceNote, 'Short note (optional)')),
          const SizedBox(width: 8),
          IconButton(
              onPressed: _addEvidence,
              color: _pink,
              icon: const Icon(Icons.add_circle)),
        ]),
      ]);

  Widget _linkChips() => _removableChips(
          _links
              .map((item) =>
                  '${_label(item['platform'] ?? '')}: ${item['url'] ?? ''}')
              .toList(), (index) {
        setState(() => _links.removeAt(index));
        _queueSave();
      });

  Widget _evidenceChips() => _removableChips(
          _evidence
              .map((item) =>
                  '${_display(item['evidence_type'] ?? '')}${(item['url'] ?? '').isNotEmpty ? ': ${item['url']}' : ''}')
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
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  Widget _reviewLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 145,
              child: Text(label,
                  style: const TextStyle(color: Color(0xff716b7d)))),
          Expanded(
              child: Text(value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  String _display(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  static String _label(String value) =>
      value.isEmpty ? '' : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
            color: const Color(0xfffff4f7),
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xfff43f75)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ]),
      );
}
