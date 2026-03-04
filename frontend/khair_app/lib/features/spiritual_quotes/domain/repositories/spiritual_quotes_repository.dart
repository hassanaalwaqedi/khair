import '../entities/spiritual_quote.dart';

abstract class SpiritualQuotesRepository {
  Future<SpiritualQuote?> getRandomQuote({
    required QuoteLocation location,
    bool refresh = false,
  });

  bool get startupShownThisSession;

  void markStartupShown();
}
