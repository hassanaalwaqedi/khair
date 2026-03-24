import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../domain/entities/spiritual_quote.dart';
import '../../domain/repositories/spiritual_quotes_repository.dart';

/// Compact, elegant Quran/Hadith card with auto-rotate and fade animation.
/// Uses soft Islamic green card — the ONLY green element on the homepage.
class QuoteRotator extends StatefulWidget {
  final QuoteLocation location;
  const QuoteRotator({super.key, this.location = QuoteLocation.home});

  @override
  State<QuoteRotator> createState() => _QuoteRotatorState();
}

class _QuoteRotatorState extends State<QuoteRotator>
    with SingleTickerProviderStateMixin {
  late final SpiritualQuotesRepository _repository;
  List<SpiritualQuote> _quotes = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _timer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _repository = getIt<SpiritualQuotesRepository>();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final quotes = await _repository.getQuotesByLocation(location: widget.location);
      if (!mounted) return;
      if (quotes.isNotEmpty) { _setQuotes(quotes); return; }
    } catch (_) {}
    try {
      final single = await _repository.getRandomQuote(location: widget.location);
      if (!mounted) return;
      if (single != null) { _setQuotes([single]); return; }
    } catch (_) {}
    if (!mounted) return;
    setState(() { _isLoading = false; _hasError = true; });
  }

  void _setQuotes(List<SpiritualQuote> quotes) {
    setState(() { _quotes = quotes; _isLoading = false; _currentIndex = 0; });
    _animCtrl.forward(from: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_quotes.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _nextQuote());
  }

  void _nextQuote() {
    if (_quotes.isEmpty) return;
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = (_currentIndex + 1) % _quotes.length);
      _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmer(context);
    if (_hasError || _quotes.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quote = _quotes[_currentIndex];
    final isQuran = quote.type == SpiritualQuoteType.quran;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Soft Islamic green — the only green element on homepage
          color: isDark
              ? KhairColors.islamicGreenDark.withValues(alpha: 0.3)
              : KhairColors.islamicGreenLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? KhairColors.islamicGreen.withValues(alpha: 0.2)
                : KhairColors.islamicGreen.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: KhairColors.islamicGreen.withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isQuran ? Icons.menu_book_rounded : Icons.auto_stories_rounded,
                  color: KhairColors.islamicGreen, size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isQuran ? 'Quran' : 'Hadith',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: KhairColors.islamicGreen,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Icon(Icons.format_quote_rounded,
                  color: KhairColors.islamicGreen.withValues(alpha: 0.3), size: 22),
            ]),
            const SizedBox(height: 10),
            // Quote text
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    quote.textAr,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                      color: isDark ? KhairColors.darkTextPrimary : KhairColors.islamicGreenDark,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '— ${quote.source} (${quote.reference})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: KhairColors.islamicGreen.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Dots
            if (_quotes.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_quotes.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentIndex ? 14 : 5, height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i == _currentIndex
                        ? KhairColors.islamicGreen
                        : KhairColors.islamicGreen.withValues(alpha: 0.2),
                  ),
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isDark
              ? KhairColors.islamicGreenDark.withValues(alpha: 0.15)
              : KhairColors.islamicGreenLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: KhairColors.islamicGreen.withValues(alpha: 0.4),
          ),
        )),
      ),
    );
  }
}
