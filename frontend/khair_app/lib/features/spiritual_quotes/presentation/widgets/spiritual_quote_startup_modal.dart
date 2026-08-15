import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
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

    // Give deep links and auth redirects a moment to settle before deciding
    // whether the startup surface belongs on the current route.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }

    // Event details is a focused conversion surface. Do not cover the hero,
    // join CTA, or location with a global startup dialog.
    final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (currentPath.startsWith('/events/')) {
      return;
    }

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

    // Routing/authentication may finish while the quote request is in flight.
    // Re-check immediately before presenting so a deep-linked event page is
    // never covered by the startup surface.
    final latestPath = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (latestPath.startsWith('/events/')) {
      return;
    }

    // The MaterialApp builder sits above the Navigator, so this state context
    // cannot present a route itself. Use GoRouter's root navigator context.
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return;
    if (!dialogContext.mounted) return;
    await showGeneralDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
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
