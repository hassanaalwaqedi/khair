import 'package:equatable/equatable.dart';

/// Report entity for content reports
class Report extends Equatable {
  final String id;
  final String? eventId;
  final String? organizerId;
  final String reporterUserId;
  final String reportType;
  final String reason;
  final String? description;
  final String status; // pending, reviewed, resolved
  final String? resolution;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const Report({
    required this.id,
    this.eventId,
    this.organizerId,
    required this.reporterUserId,
    required this.reportType,
    required this.reason,
    this.description,
    required this.status,
    this.resolution,
    required this.createdAt,
    this.reviewedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      eventId: json['event_id'],
      organizerId: json['organizer_id'],
      reporterUserId: json['reporter_user_id'],
      reportType: json['report_type'],
      reason: json['reason'],
      description: json['description'],
      status: json['status'],
      resolution: json['resolution'],
      createdAt: DateTime.parse(json['created_at']),
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isReviewed => status == 'reviewed';
  bool get isResolved => status == 'resolved';

  @override
  List<Object?> get props => [
        id,
        eventId,
        organizerId,
        reporterUserId,
        reportType,
        reason,
        description,
        status,
        resolution,
        createdAt,
        reviewedAt,
      ];
}

/// Admin dashboard stats
class AdminStats extends Equatable {
  final int pendingOrganizers;
  final int pendingEvents;
  final int pendingReports;
  final int totalOrganizers;
  final int totalEvents;
  final int totalUsers;

  const AdminStats({
    this.pendingOrganizers = 0,
    this.pendingEvents = 0,
    this.pendingReports = 0,
    this.totalOrganizers = 0,
    this.totalEvents = 0,
    this.totalUsers = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      pendingOrganizers: json['pending_organizers'] ?? 0,
      pendingEvents: json['pending_events'] ?? 0,
      pendingReports: json['pending_reports'] ?? 0,
      totalOrganizers: json['total_organizers'] ?? 0,
      totalEvents: json['total_events'] ?? 0,
      totalUsers: json['total_users'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        pendingOrganizers,
        pendingEvents,
        pendingReports,
        totalOrganizers,
        totalEvents,
        totalUsers,
      ];
}

/// User entity for admin management
class AdminUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;
  final bool isVerified;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
    this.isVerified = false,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      status: json['status'] ?? 'active',
      isVerified: json['is_verified'] == true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isOrganizer => role == 'organizer';
  bool get isSuspended => status == 'suspended';
  bool get isBanned => status == 'banned';

  @override
  List<Object?> get props => [id, name, email, role, status, isVerified, createdAt];
}

/// Verification request entity for admin review
class VerificationRequest extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String? profileImagePath;
  final String? documentPath;
  final String documentType;
  final String? notes;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VerificationRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    this.profileImagePath,
    this.documentPath,
    required this.documentType,
    this.notes,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> json) {
    return VerificationRequest(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      userEmail: json['user_email'] ?? '',
      userRole: json['user_role'] ?? '',
      profileImagePath: json['profile_image_path'],
      documentPath: json['document_path'],
      documentType: json['document_type'] ?? 'general',
      notes: json['notes'],
      status: json['status'] ?? 'pending_review',
      reviewedBy: json['reviewed_by'],
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
      reviewNotes: json['review_notes'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isPending => status == 'pending_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get needsMoreInfo => status == 'more_info_needed';

  @override
  List<Object?> get props => [id, userId, status, createdAt];
}
