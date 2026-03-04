import 'package:equatable/equatable.dart';

enum QuoteLocation {
  dashboard,
  home,
  login,
}

extension QuoteLocationX on QuoteLocation {
  String get apiValue {
    switch (this) {
      case QuoteLocation.dashboard:
        return 'dashboard';
      case QuoteLocation.home:
        return 'home';
      case QuoteLocation.login:
        return 'login';
    }
  }
}

enum SpiritualQuoteType {
  quran,
  hadith,
  unknown,
}

class SpiritualQuote extends Equatable {
  final SpiritualQuoteType type;
  final String textAr;
  final String source;
  final String reference;

  const SpiritualQuote({
    required this.type,
    required this.textAr,
    required this.source,
    required this.reference,
  });

  bool get isQuran => type == SpiritualQuoteType.quran;

  @override
  List<Object?> get props => [type, textAr, source, reference];
}
