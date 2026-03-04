import '../../domain/entities/spiritual_quote.dart';

class SpiritualQuoteModel extends SpiritualQuote {
  const SpiritualQuoteModel({
    required super.type,
    required super.textAr,
    required super.source,
    required super.reference,
  });

  factory SpiritualQuoteModel.fromJson(Map<String, dynamic> json) {
    return SpiritualQuoteModel(
      type: _parseType(json['type'] as String?),
      textAr: (json['text_ar'] as String? ?? '').trim(),
      source: (json['source'] as String? ?? '').trim(),
      reference: (json['reference'] as String? ?? '').trim(),
    );
  }

  static SpiritualQuoteType _parseType(String? value) {
    switch ((value ?? '').toLowerCase().trim()) {
      case 'quran':
        return SpiritualQuoteType.quran;
      case 'hadith':
        return SpiritualQuoteType.hadith;
      default:
        return SpiritualQuoteType.unknown;
    }
  }
}
