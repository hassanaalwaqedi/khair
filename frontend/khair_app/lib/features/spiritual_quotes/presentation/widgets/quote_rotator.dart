import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/spiritual_quote.dart';
import '../../domain/repositories/spiritual_quotes_repository.dart';

/// Rotating Quran verse / Hadith card with fade+slide animation and dots.
/// Fetches quotes from GET /quotes?location=home. Falls back to
/// GET /quotes/random if the list endpoint is unavailable.
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
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _repository = getIt<SpiritualQuotesRepository>();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Try list endpoint first
      final quotes = await _repository.getQuotesByLocation(
        location: widget.location,
      );
      if (!mounted) return;

      if (quotes.isNotEmpty) {
        _setQuotes(quotes);
        return;
      }
    } catch (_) {
      // List endpoint might not be deployed yet — fall back
    }

    // Fallback: use the /quotes/random endpoint
    try {
      final single = await _repository.getRandomQuote(
        location: widget.location,
      );
      if (!mounted) return;
      if (single != null) {
        _setQuotes([single]);
        return;
      }
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _setQuotes(List<SpiritualQuote> quotes) {
    setState(() {
      _quotes = quotes;
      _isLoading = false;
      _currentIndex = 0;
    });
    _animCtrl.forward(from: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_quotes.length <= 1) return;
    _timer = Timer.periodic(const Duration(milliseconds: 5000), (_) {
      _nextQuote();
    });
  }

  void _nextQuote() {
    if (_quotes.isEmpty) return;
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _quotes.length;
      });
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
    if (_isLoading) {
      return _buildShimmer();
    }

    if (_hasError || _quotes.isEmpty) {
      return const SizedBox.shrink();
    }

    final quote = _quotes[_currentIndex];
    final isQuran = quote.type == SpiritualQuoteType.quran;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F3D2E).withOpacity(0.85),
              const Color(0xFF14513A).withOpacity(0.75),
              const Color(0xFF0A2E1F).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A2E1F).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle pattern overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: _GeometricPatternPainter(),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quote icon + type label
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: (isQuran
                                    ? const Color(0xFFC8A951)
                                    : const Color(0xFF22C55E))
                                .withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isQuran
                                ? Icons.menu_book_rounded
                                : Icons.auto_stories_rounded,
                            color: isQuran
                                ? const Color(0xFFC8A951)
                                : const Color(0xFF22C55E),
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isQuran ? 'Quran' : 'Hadith',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.format_quote_rounded,
                          color: const Color(0xFFC8A951).withOpacity(0.4),
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Animated quote text
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            Text(
                              quote.textAr,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '— ${quote.source} (${quote.reference})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFC8A951)
                                    .withOpacity(0.9),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Dots indicator
                    if (_quotes.length > 1) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _quotes.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentIndex ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i == _currentIndex
                                  ? const Color(0xFFC8A951)
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF0F3D2E).withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle Islamic geometric pattern painter for the card background.
class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const step = 30.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), 8, paint);
        canvas.drawCircle(Offset(x + step / 2, y + step / 2), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
