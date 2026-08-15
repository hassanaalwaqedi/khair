import '../../../core/network/api_client.dart';

class ProfileOverviewDataSource {
  ProfileOverviewDataSource(this._api);

  final ApiClient _api;

  Future<ProfileOverview> load() async {
    final response = await _api.get('/me/profile-overview');
    return ProfileOverview.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<void> updatePreferences({
    bool? pushNotifications,
    bool? emailNotifications,
    String? profileVisibility,
  }) async {
    await _api.put('/profile', data: {
      if (pushNotifications != null) 'push_notifications': pushNotifications,
      if (emailNotifications != null) 'email_notifications': emailNotifications,
      if (profileVisibility != null) 'profile_visibility': profileVisibility,
    });
  }
}

class ProfileOverview {
  const ProfileOverview({
    required this.user,
    required this.stats,
    required this.organizer,
    required this.preferences,
    required this.upcomingEvents,
  });

  final ProfileUser user;
  final ProfileStats stats;
  final OrganizerStatus organizer;
  final ProfilePreferences preferences;
  final List<UpcomingProfileEvent> upcomingEvents;

  factory ProfileOverview.fromJson(Map<String, dynamic> json) {
    // Older Khair API builds accidentally serialized this field as `User`.
    // Accept it during the backend rollout while keeping `user` canonical.
    final userJson = json['user'] ?? json['User'];
    if (userJson is! Map) {
      throw const FormatException('Profile response is missing user data');
    }

    return ProfileOverview(
        user: ProfileUser.fromJson(Map<String, dynamic>.from(userJson)),
        stats: ProfileStats.fromJson(
            Map<String, dynamic>.from(json['stats'] as Map)),
        organizer: OrganizerStatus.fromJson(
            Map<String, dynamic>.from(json['organizer'] as Map)),
        preferences: ProfilePreferences.fromJson(
            Map<String, dynamic>.from(json['preferences'] as Map)),
        upcomingEvents: ((json['upcoming_events'] as List?) ?? const [])
            .map((item) => UpcomingProfileEvent.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
  }
}

class ProfileUser {
  const ProfileUser({
    required this.email,
    required this.accountType,
    required this.createdAt,
    required this.language,
    this.displayName,
    this.avatarUrl,
    this.country,
    this.city,
  });
  final String email;
  final String accountType;
  final DateTime createdAt;
  final String language;
  final String? displayName;
  final String? avatarUrl;
  final String? country;
  final String? city;

  factory ProfileUser.fromJson(Map<String, dynamic> json) => ProfileUser(
        email: json['email'] as String,
        accountType: json['account_type'] as String? ?? 'Member',
        createdAt: DateTime.parse(json['created_at'] as String),
        language: json['preferred_language'] as String? ?? 'en',
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        country: json['country'] as String?,
        city: json['city'] as String?,
      );

  String get name =>
      displayName?.trim().isNotEmpty == true ? displayName! : email;
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    return words
        .take(2)
        .map((word) => word.isEmpty ? '' : word[0])
        .join()
        .toUpperCase();
  }
}

class ProfileStats {
  const ProfileStats(this.savedEvents, this.joinedEvents, this.upcomingEvents,
      this.completion);
  final int savedEvents;
  final int joinedEvents;
  final int upcomingEvents;
  final int completion;
  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        json['saved_events'] as int? ?? 0,
        json['joined_events'] as int? ?? 0,
        json['upcoming_events'] as int? ?? 0,
        json['profile_completion'] as int? ?? 0,
      );
}

class OrganizerStatus {
  const OrganizerStatus(this.status, this.rejectionReason);
  final String status;
  final String? rejectionReason;
  factory OrganizerStatus.fromJson(Map<String, dynamic> json) =>
      OrganizerStatus(json['status'] as String? ?? 'none',
          json['rejection_reason'] as String?);
}

class ProfilePreferences {
  const ProfilePreferences(this.pushNotifications, this.emailNotifications,
      this.visibility, this.language, this.locationLabel);
  final bool pushNotifications;
  final bool emailNotifications;
  final String visibility;
  final String language;
  final String locationLabel;
  factory ProfilePreferences.fromJson(Map<String, dynamic> json) =>
      ProfilePreferences(
        json['push_notifications'] as bool? ?? true,
        json['email_notifications'] as bool? ?? true,
        json['profile_visibility'] as String? ?? 'private',
        json['language'] as String? ?? 'en',
        json['location_label'] as String? ?? 'Not set',
      );
}

class UpcomingProfileEvent {
  const UpcomingProfileEvent({
    required this.id,
    required this.title,
    required this.startDate,
    required this.location,
    required this.status,
    required this.isOnline,
    this.imageUrl,
  });
  final String id;
  final String title;
  final DateTime startDate;
  final String location;
  final String status;
  final bool isOnline;
  final String? imageUrl;
  factory UpcomingProfileEvent.fromJson(Map<String, dynamic> json) =>
      UpcomingProfileEvent(
        id: json['event_id'] as String,
        title: json['title'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        location: json['location'] as String? ?? 'Location to be announced',
        status: json['attendance_status'] as String? ?? 'confirmed',
        isOnline: json['is_online'] as bool? ?? false,
        imageUrl: json['image_url'] as String?,
      );
}
