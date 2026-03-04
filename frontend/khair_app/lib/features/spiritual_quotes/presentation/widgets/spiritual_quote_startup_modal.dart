import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../tokens/tokens.dart';
import '../../domain/entities/spiritual_quote.dart';
import '../../domain/repositories/spiritual_quotes_repository.dart';
import 'spiritual_quote_card.dart';

class SpiritualQuoteStartupModal extends StatefulWidget {
  final Widget child;

  const SpiritualQuoteStartupModal({
    super.key,
    required this.child,
  });

  @override
  State<SpiritualQuoteStartupModal> createState() =>
      _SpiritualQuoteStartupModalState();
}

class _SpiritualQuoteStartupModalState
    extends State<SpiritualQuoteStartupModal> {
  late final SpiritualQuotesRepository _repository;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _repository = getIt<SpiritualQuotesRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupQuote());
  }

  Future<void> _showStartupQuote() async {
    if (!mounted || _checked) {
      return;
    }
    _checked = true;

    if (_repository.startupShownThisSession) {
      return;
    }
    _repository.markStartupShown();

    SpiritualQuote? quote;
    try {
      quote = await _repository.getRandomQuote(location: QuoteLocation.home);
    } catch (_) {
      quote = null;
    }

    if (!mounted || quote == null) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'spiritual_quote',
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        final l10n = AppLocalizations.of(context);
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n?.spiritualQuoteTitle ?? 'Spiritual Reflection',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      SpiritualQuoteCard(
                        quote: quote!,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
