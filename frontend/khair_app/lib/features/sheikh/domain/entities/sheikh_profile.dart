/// Sheikh profile entity for the sheikh directory.
class SheikhProfile {
  final String id;
  final String userId;
  final String? displayName;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? country;
  final String? specialization;
  final String? ijazahInfo;
  final List<String> certifications;
  final int? yearsOfExperience;
  final String verificationStatus;
  final DateTime createdAt;

  const SheikhProfile({
    required this.id,
    required this.userId,
    this.displayName,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.city,
    this.country,
    this.specialization,
    this.ijazahInfo,
    this.certifications = const [],
    this.yearsOfExperience,
    required this.verificationStatus,
    required this.createdAt,
  });

  factory SheikhProfile.fromJson(Map<String, dynamic> json) {
    return SheikhProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      specialization: json['specialization'] as String?,
      ijazahInfo: json['ijazah_info'] as String?,
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      yearsOfExperience: json['years_of_experience'] as int?,
      verificationStatus: json['verification_status'] as String? ?? 'unverified',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// The display name or first part of email
  String get name => displayName ?? email.split('@').first;

  bool get isVerified => verificationStatus == 'verified';
}
