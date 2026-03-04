/// Country model matching the backend countries table
class Country {
  final int id;
  final String name;
  final String isoCode;
  final String? iso3Code;
  final String phoneCode;
  final String flagEmoji;
  final String region;

  const Country({
    required this.id,
    required this.name,
    required this.isoCode,
    this.iso3Code,
    required this.phoneCode,
    required this.flagEmoji,
    required this.region,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as int,
      name: json['name'] as String,
      isoCode: json['iso_code'] as String,
      iso3Code: json['iso3_code'] as String?,
      phoneCode: json['phone_code'] as String,
      flagEmoji: json['flag_emoji'] as String? ?? '',
      region: json['region'] as String? ?? 'Other',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iso_code': isoCode,
        'iso3_code': iso3Code,
        'phone_code': phoneCode,
        'flag_emoji': flagEmoji,
        'region': region,
      };

  /// Display string: "🇸🇦 Saudi Arabia (+966)"
  String get displayLabel => '$flagEmoji $name ($phoneCode)';

  /// Short display: "🇸🇦 Saudi Arabia"
  String get shortLabel => '$flagEmoji $name';

  @override
  String toString() => shortLabel;
}
