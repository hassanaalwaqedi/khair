import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../locale/locale_bloc.dart';
import '../locale/l10n_extension.dart';

/// A compact language switcher widget supporting English, Arabic, and Turkish.
class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;

  /// If true, uses a light style (white border/text) suitable for dark backgrounds.
  final bool lightStyle;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.lightStyle = false,
  });

  static const _languages = [
    _LangOption('en', '🇬🇧', 'English'),
    _LangOption('ar', '🇸🇦', 'العربية'),
    _LangOption('tr', '🇹🇷', 'Türkçe'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, state) {
        final current = _languages.firstWhere(
          (l) => l.code == state.locale.languageCode,
          orElse: () => _languages.first,
        );

        return PopupMenuButton<String>(
          onSelected: (code) {
            context.read<LocaleBloc>().add(ChangeLocale(Locale(code)));
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => _languages
              .where((l) => l.code != current.code)
              .map(
                (l) => PopupMenuItem<String>(
                  value: l.code,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        l.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: lightStyle
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              border: Border.all(
                color: lightStyle
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  current.flag,
                  style: const TextStyle(fontSize: 18),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    current.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lightStyle
                          ? Colors.white.withValues(alpha: 0.9)
                          : null,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: lightStyle
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.grey[600],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LangOption {
  final String code;
  final String flag;
  final String label;
  const _LangOption(this.code, this.flag, this.label);
}
