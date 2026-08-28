import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────── Events ────────

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ToggleTheme extends ThemeEvent {
  const ToggleTheme();
}

class SetThemeMode extends ThemeEvent {
  final ThemeMode mode;
  const SetThemeMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class LoadSavedTheme extends ThemeEvent {
  const LoadSavedTheme();
}

// ──────── State ────────

class ThemeState extends Equatable {
  final ThemeMode themeMode;

  const ThemeState({this.themeMode = ThemeMode.system});

  bool get isDark => themeMode == ThemeMode.dark;
  bool get isLight => themeMode == ThemeMode.light;
  bool get isSystem => themeMode == ThemeMode.system;

  ThemeState copyWith({ThemeMode? themeMode}) {
    return ThemeState(themeMode: themeMode ?? this.themeMode);
  }

  @override
  List<Object?> get props => [themeMode];
}

// ──────── Bloc ────────

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const _themeKey = 'app_theme_mode_v1';

  ThemeBloc() : super(const ThemeState()) {
    on<ToggleTheme>(_onToggle);
    on<SetThemeMode>(_onSetMode);
    on<LoadSavedTheme>(_onLoadSavedTheme);
    add(const LoadSavedTheme());
  }

  Future<void> _onToggle(ToggleTheme event, Emitter<ThemeState> emit) async {
    final nextMode =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _save(nextMode);
    emit(state.copyWith(themeMode: nextMode));
  }

  Future<void> _onSetMode(SetThemeMode event, Emitter<ThemeState> emit) async {
    await _save(event.mode);
    emit(state.copyWith(themeMode: event.mode));
  }

  Future<void> _onLoadSavedTheme(
      LoadSavedTheme event, Emitter<ThemeState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    final mode = switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => state.themeMode,
    };
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> _save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
}
