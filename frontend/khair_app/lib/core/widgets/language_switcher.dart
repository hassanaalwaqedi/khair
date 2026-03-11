import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../locale/locale_bloc.dart';
import '../locale/l10n_extension.dart';

/// A compact language switcher widget that toggles between English and Arabic.
/// Shows country flags for each language.
class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;

  /// If true, uses a light style (white border/text) suitable for dark backgrounds.
  final bool lightStyle;

  const LanguageSwitcher({
    super.key,
    this.showLabel = true,
    this.lightStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, state) {
        final isArabic = state.locale.languageCode == 'ar';
        // Show the flag of the language to switch TO
        final targetFlag = isArabic ? '🇬🇧' : '🇸🇦';
        final targetLabel = isArabic ? context.l10n.english : context.l10n.arabic;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final newLocale =
                  isArabic ? const Locale('en') : const Locale('ar');
              context.read<LocaleBloc>().add(ChangeLocale(newLocale));
            },
            borderRadius: BorderRadius.circular(12),
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
                    targetFlag,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      targetLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: lightStyle
                            ? Colors.white.withValues(alpha: 0.9)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
