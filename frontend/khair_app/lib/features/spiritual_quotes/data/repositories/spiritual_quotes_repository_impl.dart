import '../../domain/entities/spiritual_quote.dart';
import '../../domain/repositories/spiritual_quotes_repository.dart';
import '../datasources/spiritual_quotes_remote_datasource.dart';

class SpiritualQuotesRepositoryImpl implements SpiritualQuotesRepository {
  final SpiritualQuotesRemoteDataSource _remoteDataSource;
  final Map<QuoteLocation, SpiritualQuote> _sessionCache = {};
  bool _startupShown = false;

  SpiritualQuotesRepositoryImpl(this._remoteDataSource);

  @override
  Future<SpiritualQuote?> getRandomQuote({
    required QuoteLocation location,
    bool refresh = false,
  }) async {
    if (!refresh) {
      final cached = _sessionCache[location];
      if (cached != null) {
        return cached;
      }
    }

    final quote = await _remoteDataSource.getRandomQuote(location: location);
    if (quote != null) {
      _sessionCache[location] = quote;
    }
    return quote;
  }

  @override
  Future<List<SpiritualQuote>> getQuotesByLocation({
    required QuoteLocation location,
  }) async {
    return await _remoteDataSource.getQuotesByLocation(location: location);
  }

  @override
  bool get startupShownThisSession => _startupShown;

  @override
  void markStartupShown() {
    _startupShown = true;
  }
}
