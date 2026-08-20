import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_locale_helper.dart'
    if (dart.library.html) 'web_locale_helper_web.dart';

// Events
abstract class LocaleEvent extends Equatable {
  const LocaleEvent();
  @override
  List<Object?> get props => [];
}

class ChangeLocale extends LocaleEvent {
  final Locale locale;
  const ChangeLocale(this.locale);
  @override
  List<Object?> get props => [locale];
}

class LoadSavedLocale extends LocaleEvent {
  const LoadSavedLocale();
}

class UseDeviceLocale extends LocaleEvent {
  const UseDeviceLocale();
}

// State
class LocaleState extends Equatable {
  final Locale locale;
  const LocaleState({required this.locale});
  @override
  List<Object?> get props => [locale];
}

// BLoC
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  // Versioned so legacy automatic/default values do not override the device
  // language after this behavior is enabled.
  static const _localeKey = 'app_locale_override_v2';
  static const supportedLanguageCodes = {'en', 'ar', 'tr'};

  LocaleBloc()
      : super(LocaleState(
            locale: resolveDeviceLocale(
                WidgetsBinding.instance.platformDispatcher.locales))) {
    on<LoadSavedLocale>(_onLoadSavedLocale);
    on<ChangeLocale>(_onChangeLocale);
    on<UseDeviceLocale>(_onUseDeviceLocale);
  }

  /// Resolves the first supported language from the device language list.
  /// English is the safe fallback when the device uses another language.
  static Locale resolveDeviceLocale(Iterable<Locale> deviceLocales) {
    for (final locale in deviceLocales) {
      final code = locale.languageCode.toLowerCase();
      if (supportedLanguageCodes.contains(code)) return Locale(code);
    }
    return const Locale('en');
  }

  Future<void> _onLoadSavedLocale(
    LoadSavedLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = _supportedCode(prefs.getString(_localeKey));
    final deviceLocale = resolveDeviceLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    final languageCode = savedLocale ?? deviceLocale.languageCode;
    setWebLocale(languageCode, languageCode == 'ar' ? 'rtl' : 'ltr');
    emit(LocaleState(locale: Locale(languageCode)));
  }

  Future<void> _onChangeLocale(
    ChangeLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final languageCode = _supportedCode(event.locale.languageCode) ?? 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, languageCode);
    setWebLocale(languageCode, languageCode == 'ar' ? 'rtl' : 'ltr');
    emit(LocaleState(locale: Locale(languageCode)));
  }

  Future<void> _onUseDeviceLocale(
    UseDeviceLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);
    final locale = resolveDeviceLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    setWebLocale(
        locale.languageCode, locale.languageCode == 'ar' ? 'rtl' : 'ltr');
    emit(LocaleState(locale: locale));
  }

  String? _supportedCode(String? code) {
    if (code == null) return null;
    final normalized = code.toLowerCase();
    return supportedLanguageCodes.contains(normalized) ? normalized : null;
  }
}
