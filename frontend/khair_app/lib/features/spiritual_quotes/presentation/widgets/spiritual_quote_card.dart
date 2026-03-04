import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../tokens/tokens.dart';
import '../../domain/entities/spiritual_quote.dart';

class SpiritualQuoteCard extends StatelessWidget {
  final SpiritualQuote quote;
  final bool compact;
  final VoidCallback? onClose;

  const SpiritualQuoteCard({
    super.key,
    required this.quote,
    this.compact = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isQuran = quote.isQuran;
    final typeLabel = isQuran
        ? (l10n?.spiritualQuoteTypeQuran ?? 'Quran')
        : (l10n?.spiritualQuoteTypeHadith ?? 'Hadith');

    final gradient = isQuran
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4FBF8), Color(0xFFE7F6EF), Color(0xFFFAFEFC)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9EE), Color(0xFFFFF4DD), Color(0xFFFFFCF3)],
          );

    final accent = isQuran ? AppColors.primary : AppColors.secondary;
    final icon = isQuran ? Icons.menu_book_rounded : Icons.auto_stories_rounded;

    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius:
            BorderRadius.circular(compact ? AppRadius.md : AppRadius.lg),
        border: Border.all(
          color: accent.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: AppShadows.md,
      ),
      padding: EdgeInsets.all(compact ? AppSpacing.x2 : AppSpacing.x3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 32 : 36,
                height: compact ? 32 : 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: compact ? 18 : 20),
              ),
              const SizedBox(width: AppSpacing.x1),
              Expanded(
                child: Text(
                  typeLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: l10n?.spiritualQuoteDismiss ?? 'Dismiss',
                ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.x1 : AppSpacing.x2),
          Text(
            quote.textAr,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  height: 1.9,
                  fontSize: compact ? 18 : 22,
                ),
          ),
          SizedBox(height: compact ? AppSpacing.x1 : AppSpacing.x2),
          Text(
            '${quote.source} • ${quote.reference}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
