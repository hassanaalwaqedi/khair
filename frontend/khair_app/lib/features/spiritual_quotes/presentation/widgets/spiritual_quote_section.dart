import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../tokens/tokens.dart';
import '../../domain/entities/spiritual_quote.dart';
import '../../domain/repositories/spiritual_quotes_repository.dart';
import 'spiritual_quote_card.dart';

class SpiritualQuoteSection extends StatefulWidget {
  final QuoteLocation location;
  final bool compact;
  final bool showFallback;

  const SpiritualQuoteSection({
    super.key,
    required this.location,
    this.compact = true,
    this.showFallback = true,
  });

  @override
  State<SpiritualQuoteSection> createState() => _SpiritualQuoteSectionState();
}

class _SpiritualQuoteSectionState extends State<SpiritualQuoteSection> {
  late final SpiritualQuotesRepository _repository;

  SpiritualQuote? _quote;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _repository = getIt<SpiritualQuotesRepository>();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final quote = await _repository.getRandomQuote(location: widget.location);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _QuoteLoadingCard(compact: widget.compact);
    }

    if (_quote != null) {
      return AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        child: SpiritualQuoteCard(
          key: ValueKey('${widget.location.apiValue}-${_quote.hashCode}'),
          quote: _quote!,
          compact: widget.compact,
        ),
      );
    }

    if (!widget.showFallback) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          widget.compact ? AppRadius.md : AppRadius.lg,
        ),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(widget.compact ? AppSpacing.x2 : AppSpacing.x3),
      child: Row(
        children: [
          Container(
            width: widget.compact ? 30 : 36,
            height: widget.compact ? 30 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: widget.compact ? 18 : 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              l10n?.spiritualQuoteUnavailable ??
                  'A spiritual reminder is not available right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          if (_hasError)
            TextButton(
              onPressed: _loadQuote,
              child: Text(l10n?.retry ?? 'Retry'),
            ),
        ],
      ),
    );
  }
}

class _QuoteLoadingCard extends StatelessWidget {
  final bool compact;

  const _QuoteLoadingCard({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(compact ? AppRadius.md : AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(compact ? AppSpacing.x2 : AppSpacing.x3),
      child: Row(
        children: [
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.disabled.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Container(
              height: compact ? 16 : 20,
              decoration: BoxDecoration(
                color: AppColors.disabled.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
