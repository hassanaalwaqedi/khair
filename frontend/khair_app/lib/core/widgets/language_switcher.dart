import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../locale/locale_bloc.dart';
import '../../l10n/generated/app_localizations.dart';

/// A compact language switcher widget that toggles between English and Arabic.
class LanguageSwitcher extends StatelessWidget {
  final bool showLabel;

  const LanguageSwitcher({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, state) {
        final isArabic = state.locale.languageCode == 'ar';
        return InkWell(
          onTap: () {
            final newLocale =
                isArabic ? const Locale('en') : const Locale('ar');
            context.read<LocaleBloc>().add(ChangeLocale(newLocale));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 18),
                if (showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? l10n.english : l10n.arabic,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
