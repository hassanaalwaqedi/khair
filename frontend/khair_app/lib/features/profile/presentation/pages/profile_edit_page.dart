import 'package:khair_app/core/locale/l10n_extension.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/locale/locale_bloc.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/navigation.dart';
import '../../../../core/utils/image_upload_client.dart';
import '../../../../core/utils/image_upload_validator.dart';
import '../../../../core/widgets/discard_changes_dialog.dart';

const _rose = Color(0xFFF43F75);
const _roseSoft = Color(0xFFFFF1F5);
const _ink = Color(0xFF171126);
const _muted = Color(0xFF726B7B);
const _border = Color(0xFFEAE5E8);

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  String _language = 'en';
  String? _avatarUrl;
  Uint8List? _preview;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _hydrating = false;
  bool _hasInitialValues = false;
  bool _allowPop = false;
  bool _discardDialogOpen = false;
  String? _error;
  String _initialName = '';
  String _initialCountry = '';
  String _initialCity = '';
  String _initialLanguage = 'en';

  @override
  void initState() {
    super.initState();
    for (final controller in [_name, _country, _city]) {
      controller.addListener(_onFieldChanged);
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await getIt<Dio>().get('/profile');
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      if (!mounted) return;
      _hydrating = true;
      _name.text = data['display_name']?.toString() ?? '';
      _country.text = data['country']?.toString() ?? '';
      _city.text = data['city']?.toString() ?? '';
      _language = data['preferred_language']?.toString() ?? 'en';
      _avatarUrl = data['avatar_url']?.toString();
      _captureInitialValues();
      _hydrating = false;
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        _captureInitialValues();
        setState(() {
          _loading = false;
          _error = 'We couldn’t load your profile details.';
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploading) return;
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final issue = await inspectImageUpload(filename: image.name, bytes: bytes);
    if (!mounted) return;
    setState(() {
      _preview = bytes;
      _uploading = true;
      _error = null;
    });
    if (issue != null) {
      setState(() {
        _uploading = false;
        _error = imageUploadIssueMessage(issue);
      });
      return;
    }
    try {
      final url = await uploadImageBytes(
        dio: getIt<Dio>(),
        path: '/profile/upload-avatar',
        bytes: bytes,
        filename: image.name,
      );
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error =
              'We couldn’t upload that photo. Use a JPG, PNG, or WebP under 5 MB.';
          _error = imageUploadFailureMessage(error);
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await getIt<Dio>().put('/profile', data: {
        'display_name': _name.text.trim(),
        'country': _country.text.trim(),
        'city': _city.text.trim(),
        'preferred_language': _language,
      });
      if (mounted) {
        context.read<LocaleBloc>().add(ChangeLocale(Locale(_language)));
        _captureInitialValues();
        context.popOrGo('/profile', result: true);
      }
    } on DioException catch (_) {
      if (mounted) {
        setState(() => _error =
            'We couldn’t save your profile. Please check the details and try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'We couldn’t save your profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _captureInitialValues() {
    _initialName = _name.text;
    _initialCountry = _country.text;
    _initialCity = _city.text;
    _initialLanguage = _language;
    _hasInitialValues = true;
  }

  bool get _hasUnsavedChanges =>
      _hasInitialValues &&
      (_name.text != _initialName ||
          _country.text != _initialCountry ||
          _city.text != _initialCity ||
          _language != _initialLanguage);

  void _onFieldChanged() {
    if (!_hydrating && mounted) setState(() {});
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop || _discardDialogOpen) return;
    if (!_hasUnsavedChanges) {
      context.popOrGo('/profile');
      return;
    }
    _discardDialogOpen = true;
    final discard = await showDiscardChangesDialog(context);
    if (!mounted) return;
    _discardDialogOpen = false;
    if (!discard) return;
    setState(() => _allowPop = true);
    context.popOrGo('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? Color(0xFF101014) : Color(0xFFFCFAFB);
    return PopScope(
      canPop: (_allowPop || !_hasUnsavedChanges) && context.canNavigateBack,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          title: Text(context.l10n.editProfile1,
              style: TextStyle(
                  color: dark ? Colors.white : _ink,
                  fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: _saving || _loading ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _rose))
                    : Text(context.l10n.save,
                        style: TextStyle(
                            color: _rose, fontWeight: FontWeight.w800)))
          ],
        ),
        body: _loading
            ? _EditSkeleton()
            : Center(
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 620),
                    child: Form(
                        key: _form,
                        child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(20, 16, 20,
                                80 + MediaQuery.viewInsetsOf(context).bottom),
                            children: [
                              Text(context.l10n.yourEventProfile,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: dark ? Colors.white : _ink)),
                              SizedBox(height: 6),
                              Text(
                                  'Keep these details current so Khair can personalize your event experience.',
                                  style: TextStyle(
                                      color:
                                          dark ? Color(0xFFC5BEC8) : _muted)),
                              SizedBox(height: 26),
                              Center(
                                  child: _AvatarEditor(
                                      preview: _preview,
                                      avatarUrl: _avatarUrl,
                                      name: _name.text,
                                      loading: _uploading,
                                      onTap: _pickAvatar)),
                              SizedBox(height: 26),
                              if (_error != null) _Error(message: _error!),
                              if (_error != null) SizedBox(height: 14),
                              _Field(
                                  controller: _name,
                                  label: context.l10n.displayName1,
                                  icon: Icons.person_outline,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Enter your display name.'
                                          : null),
                              SizedBox(height: 14),
                              _Field(
                                  controller: _country,
                                  label: context.l10n.createEventCountry,
                                  icon: Icons.public_outlined),
                              SizedBox(height: 14),
                              _Field(
                                  controller: _city,
                                  label: context.l10n.city,
                                  icon: Icons.location_city_outlined),
                              SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                  initialValue: _language,
                                  decoration: _decoration('Preferred language',
                                      Icons.language_outlined),
                                  items: [
                                    DropdownMenuItem(
                                        value: 'en',
                                        child: Text(context
                                            .l10n.registrationLanguageEnglish)),
                                    DropdownMenuItem(
                                        value: 'ar',
                                        child: Text(context
                                            .l10n.registrationLanguageArabic)),
                                    DropdownMenuItem(
                                        value: 'tr',
                                        child: Text(context
                                            .l10n.registrationLanguageTurkish))
                                  ],
                                  onChanged: (value) => setState(
                                      () => _language = value ?? 'en')),
                              SizedBox(height: 28),
                              FilledButton(
                                  onPressed: _saving ? null : _save,
                                  style: FilledButton.styleFrom(
                                      backgroundColor: _rose,
                                      minimumSize: const Size.fromHeight(52)),
                                  child: Text(
                                      _saving ? 'Saving…' : 'Save changes')),
                            ])))),
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor(
      {required this.preview,
      required this.avatarUrl,
      required this.name,
      required this.loading,
      required this.onTap});
  final Uint8List? preview;
  final String? avatarUrl;
  final String name;
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(99),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_rose, Color(0xFFFF8AAF)])),
            child: ClipOval(
                child: Stack(fit: StackFit.expand, children: [
              if (preview != null)
                Image.memory(preview!,
                    fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200)
              else if (avatarUrl?.isNotEmpty == true)
                Image.network(ApiConfig.resolveUrl(avatarUrl),
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                    cacheHeight: 200,
                    errorBuilder: (_, __, ___) => _AvatarInitial(name))
              else
                _AvatarInitial(name),
              if (loading)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                ),
            ]))),
        PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: _rose,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3)),
                child: Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 16)))
      ]));
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Center(
      child: Text(name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 34)));
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller,
      required this.label,
      required this.icon,
      this.validator});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
      controller: controller,
      validator: validator,
      decoration: _decoration(label, icon));
}

InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _rose),
    filled: true,
    fillColor: _roseSoft.withValues(alpha: .45),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _rose, width: 2)));

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: _roseSoft,
          border: Border.all(color: _rose.withValues(alpha: .25)),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.info_outline, color: _rose),
        SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: _ink)))
      ]));
}

class _EditSkeleton extends StatelessWidget {
  const _EditSkeleton();
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(color: _rose)),
        SizedBox(height: 16),
        Text(context.l10n.loadingYourProfile)
      ]));
}
