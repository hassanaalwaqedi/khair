import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_locale_helper.dart' if (dart.library.html) 'web_locale_helper_web.dart';

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

// State
class LocaleState extends Equatable {
  final Locale locale;
  const LocaleState({required this.locale});
  @override
  List<Object?> get props => [locale];
}

// BLoC
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  static const _localeKey = 'app_locale';

  LocaleBloc() : super(const LocaleState(locale: Locale('en'))) {
    on<LoadSavedLocale>(_onLoadSavedLocale);
    on<ChangeLocale>(_onChangeLocale);
  }

  Future<void> _onLoadSavedLocale(
    LoadSavedLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale != null) {
      setWebLocale(savedLocale, savedLocale == 'ar' ? 'rtl' : 'ltr');
      emit(LocaleState(locale: Locale(savedLocale)));
    }
  }

  Future<void> _onChangeLocale(
    ChangeLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, event.locale.languageCode);
    setWebLocale(event.locale.languageCode, event.locale.languageCode == 'ar' ? 'rtl' : 'ltr');
    emit(LocaleState(locale: event.locale));
  }
}
