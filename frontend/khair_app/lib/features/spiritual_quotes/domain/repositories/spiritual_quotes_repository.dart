import '../entities/spiritual_quote.dart';

abstract class SpiritualQuotesRepository {
  Future<SpiritualQuote?> getRandomQuote({
    required QuoteLocation location,
    bool refresh = false,
  });

  Future<List<SpiritualQuote>> getQuotesByLocation({
    required QuoteLocation location,
  });

  bool get startupShownThisSession;

  void markStartupShown();
}
